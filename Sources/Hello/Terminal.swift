import AppKit
import SwiftUI

// MARK: - Historique des commandes

/// Commandes lancées depuis Hello + historique zsh (~/.zsh_history), les plus récentes d'abord.
enum ShellHistory {
    private static var own: [String] = UserDefaults.standard.stringArray(forKey: "shellHistory") ?? []
    private static var zsh: [(command: String, folded: String)]?

    static func record(_ command: String) {
        own.removeAll { $0 == command }
        own.insert(command, at: 0)
        if own.count > 300 { own.removeLast(own.count - 300) }
        UserDefaults.standard.set(own, forKey: "shellHistory")
    }

    static func search(_ query: String, limit: Int) -> [String] {
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        var seen = Set<String>()
        var out: [String] = []
        func scan(_ command: String, _ folded: @autoclosure () -> String) -> Bool {
            guard seen.insert(command).inserted, q.isEmpty || folded().contains(q) else { return false }
            out.append(command)
            return out.count >= limit
        }
        for command in own where scan(command, Fuzzy.fold(command)) { return out }
        for entry in zshHistory() where scan(entry.command, entry.folded) { return out }
        return out
    }

    static func clear() {
        own = []
        UserDefaults.standard.set(own, forKey: "shellHistory")
    }

    /// Lu (et normalisé pour la recherche) une seule fois, à la première utilisation.
    private static func zshHistory() -> [(command: String, folded: String)] {
        guard AppSettings.shared.zshHistory else { return [] }
        if let zsh { return zsh }
        let url = URL(fileURLWithPath: Shell.home + "/.zsh_history")
        guard let data = try? Data(contentsOf: url) else { zsh = []; return [] }
        let lines = String(decoding: data, as: UTF8.self).split(separator: "\n").suffix(4000)
        var seen = Set<String>()
        var list: [(command: String, folded: String)] = []
        for line in lines.reversed() {
            var command = String(line)
            if command.hasPrefix(": "), let semicolon = command.firstIndex(of: ";") {
                command = String(command[command.index(after: semicolon)...])
            }
            command = command.trimmingCharacters(in: .whitespaces)
            guard command.count > 1, !command.hasSuffix("\\"), seen.insert(command).inserted else { continue }
            list.append((command, Fuzzy.fold(command)))
            if list.count >= 1500 { break }
        }
        zsh = list
        return list
    }
}

// MARK: - Dossiers fréquents (à la zoxide)

enum FolderJump {
    private static var zoxide: [(path: String, score: Double)]?
    private static var loading = false

    /// Dossiers déjà ouverts via Hello (et ceux de zoxide s'il est installé) dont le nom correspond.
    static func candidates(_ query: String, limit: Int) -> [String] {
        let q = Fuzzy.fold(query.trimmingCharacters(in: .whitespaces))
        guard !q.isEmpty else { return [] }
        var scored: [String: Int] = [:]
        for id in Usage.records.keys where id.hasPrefix("path:") {
            let path = String(id.dropFirst(5))
            guard let s = Fuzzy.score(q, Fuzzy.fold((path as NSString).lastPathComponent)) else { continue }
            scored[path] = max(scored[path] ?? 0, s + Usage.boost(id, query: query))
        }
        for entry in zoxideEntries() {
            guard let s = Fuzzy.score(q, Fuzzy.fold((entry.path as NSString).lastPathComponent)) else { continue }
            scored[entry.path] = max(scored[entry.path] ?? 0, s + min(200, Int(entry.score * 2)))
        }
        return Array(scored.sorted { $0.value > $1.value }.lazy.map(\.key).filter(Shell.isFolder).prefix(limit))
    }

    private static func zoxideEntries() -> [(path: String, score: Double)] {
        if let zoxide { return zoxide }
        guard !loading, AppSettings.shared.useZoxide, Shell.isCommand("zoxide") else { return [] }
        loading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let output = Shell.capture("zoxide query --list --score")
            let entries = output.split(separator: "\n").compactMap { line -> (String, Double)? in
                let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
                guard parts.count == 2, let score = Double(parts[0]) else { return nil }
                return (String(parts[1]), score)
            }
            DispatchQueue.main.async {
                zoxide = entries
                Controller.shared.model.refresh()
            }
        }
        return []
    }
}

// MARK: - Git

enum Git {
    /// Branche courante en lisant .git/HEAD (aucun processus lancé).
    static func branch(_ path: String) -> String? {
        let fm = FileManager.default
        var gitDir = path + "/.git"
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: gitDir, isDirectory: &isDir) else { return nil }
        if !isDir.boolValue {
            guard let file = try? String(contentsOfFile: gitDir, encoding: .utf8),
                  let range = file.range(of: "gitdir: ") else { return nil }
            gitDir = file[range.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if !gitDir.hasPrefix("/") { gitDir = path + "/" + gitDir }
        }
        guard let head = try? String(contentsOfFile: gitDir + "/HEAD", encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) else { return nil }
        if head.hasPrefix("ref: refs/heads/") { return String(head.dropFirst(16)) }
        return String(head.prefix(7))
    }
}

// MARK: - Processus et ports

struct ProcessEntry {
    let pid: Int32
    let name: String
    let path: String
    let app: NSRunningApplication?
}

enum Processes {
    private static var cache: (date: Date, list: [ProcessEntry])?

    /// Processus de l'utilisateur (ps), enrichis avec les apps (nom, icône). Mis en cache 3 s.
    static func list() -> [ProcessEntry] {
        if let cache, Date().timeIntervalSince(cache.date) < 3 { return cache.list }
        let apps = Dictionary(NSWorkspace.shared.runningApplications.map { ($0.processIdentifier, $0) },
                              uniquingKeysWith: { a, _ in a })
        let me = ProcessInfo.processInfo.processIdentifier
        let output = Shell.captureDirect("/bin/ps", ["-xo", "pid=,comm="])
        let list = output.split(separator: "\n").compactMap { line -> ProcessEntry? in
            let parts = line.trimmingCharacters(in: .whitespaces).split(separator: " ", maxSplits: 1)
            guard parts.count == 2, let pid = Int32(parts[0]), pid != me else { return nil }
            let path = String(parts[1])
            let app = apps[pid]
            return ProcessEntry(pid: pid, name: app?.localizedName ?? (path as NSString).lastPathComponent, path: path, app: app)
        }
        cache = (Date(), list)
        return list
    }

    static func search(_ query: String) -> [ProcessEntry] {
        let q = Fuzzy.fold(query)
        return list()
            .filter { q.isEmpty || Fuzzy.fold($0.name).contains(q) }
            .sorted { ($0.app != nil ? 0 : 1, $0.name.count) < ($1.app != nil ? 0 : 1, $1.name.count) }
            .prefix(20).map { $0 }
    }

    @discardableResult
    static func kill(_ p: ProcessEntry, force: Bool) -> Bool {
        cache = nil
        if let app = p.app { return force ? app.forceTerminate() : app.terminate() }
        return Darwin.kill(p.pid, force ? SIGKILL : SIGTERM) == 0
    }

    static func invalidate() { cache = nil }
}

struct PortEntry {
    let port: Int
    let pid: Int32
    let command: String
    let address: String
}

enum Ports {
    private static var cache: (date: Date, list: [PortEntry])?
    private static var loading = false

    /// Ports TCP en écoute (lsof, en arrière-plan). nil pendant le premier chargement.
    static func listening() -> [PortEntry]? {
        if let cache, Date().timeIntervalSince(cache.date) < 4 { return cache.list }
        if !loading {
            loading = true
            DispatchQueue.global(qos: .userInitiated).async {
                let output = Shell.captureDirect("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN", "-Fpcn"])
                var list: [PortEntry] = []
                var pid: Int32 = 0
                var command = ""
                var seen = Set<String>()
                for line in output.split(separator: "\n") {
                    guard let tag = line.first else { continue }
                    let value = String(line.dropFirst())
                    switch tag {
                    case "p": pid = Int32(value) ?? 0
                    case "c": command = value
                    case "n":
                        guard let colon = value.lastIndex(of: ":"), let port = Int(value[value.index(after: colon)...]),
                              seen.insert("\(pid):\(port)").inserted else { continue }
                        list.append(PortEntry(port: port, pid: pid, command: command, address: String(value[..<colon])))
                    default: break
                    }
                }
                list.sort { $0.port < $1.port }
                DispatchQueue.main.async {
                    cache = (Date(), list)
                    loading = false
                    Controller.shared.model.refresh()
                }
            }
        }
        return cache?.list
    }

    static func invalidate() { cache = nil }
}

// MARK: - Réseau

enum NetInfo {
    static func addresses() -> [(interface: String, address: String)] {
        var result: [(String, String)] = []
        var list: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&list) == 0, let first = list else { return [] }
        defer { freeifaddrs(list) }
        for ptr in sequence(first: first, next: { $0.pointee.ifa_next }) {
            let ifa = ptr.pointee
            guard let addr = ifa.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET),
                  ifa.ifa_flags & UInt32(IFF_LOOPBACK) == 0, ifa.ifa_flags & UInt32(IFF_UP) != 0 else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            guard getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0
            else { continue }
            result.append((String(cString: ifa.ifa_name), String(cString: host)))
        }
        return result
    }
}

// MARK: - Commandes personnalisées

struct CustomCommand: Codable, Identifiable, Equatable {
    enum RunMode: String, Codable, CaseIterable, Identifiable {
        case app = "halo", terminal, silent  // valeur enregistrée inchangée
        var id: String { rawValue }
        var title: String {
            switch self {
            case .app: "Dans Hello"
            case .terminal: "Dans le Terminal"
            case .silent: "En silence"
            }
        }
    }

    var id = UUID()
    var name: String
    var keyword: String
    var command: String
    var mode: RunMode

    static let examples = [
        CustomCommand(name: "Mettre à jour Homebrew", keyword: "brewup", command: "brew update && brew upgrade", mode: .terminal),
        CustomCommand(name: "Ouvrir un dépôt GitHub", keyword: "gh", command: "open https://github.com/{}", mode: .silent),
        CustomCommand(name: "Taille des dossiers ici", keyword: "du", command: "du -sh ~/{}/* | sort -h", mode: .app),
    ]
}

// MARK: - Intégration dans la recherche

extension LauncherModel {
    /// Résultats « terminal » prioritaires (affichés avant les apps).
    func terminalItems(_ q: String) -> [ResultItem] {
        guard AppSettings.shared.shellCommands else { return [] }
        let (word, rest) = Shell.splitFirst(q)

        if q.hasPrefix(">") || q.hasPrefix("$") {
            let command = q.dropFirst().trimmingCharacters(in: .whitespaces)
            var out = command.isEmpty ? [] : [runItem(command)]
            for (i, past) in ShellHistory.search(command, limit: 10).enumerated() where past != command {
                var item = runItem(past, history: true)
                item.section = i == 0 || out.count <= 1 ? "Historique" : nil
                out.append(item)
            }
            return out
        }

        switch word.lowercased() {
        case "kill", "killall", "pkill":
            return processItems(rest)
        case "port", "ports":
            return portItems(rest)
        case "ip" where rest.isEmpty:
            return ipItems()
        case "z":
            return FolderJump.candidates(rest, limit: 8).map { pathItem($0, completion: "cd " + Shell.abbreviate($0) + "/", learn: rest) }
        default:
            break
        }
        if q.hasPrefix(":"), let port = Int(q.dropFirst()) { return portItems(String(port)) }

        guard !Shell.hasOperators(q) else { return [] }
        if word == "cd" {
            var out = pathItems(rest.isEmpty ? "~" : rest, prefix: "cd ", foldersOnly: true, learn: rest)
            // « cd proj » : on propose aussi les dossiers fréquents, où qu'ils soient.
            if !rest.isEmpty && !rest.contains("/") && !rest.hasPrefix("~") && !rest.hasPrefix(".") {
                let known = Set(out.map(\.id))
                for path in FolderJump.candidates(rest, limit: 6) where !known.contains("path:" + path) {
                    var item = pathItem(path, completion: "cd " + Shell.abbreviate(path) + "/", learn: rest)
                    item.section = "Dossiers fréquents"
                    out.append(item)
                }
            }
            return out
        }
        if word == "open", !rest.isEmpty, !rest.hasPrefix("-") {
            return pathItems(rest, prefix: "open ", foldersOnly: false, learn: rest)
        }
        if q.hasPrefix("~") || q.hasPrefix("/") || q.hasPrefix("./") || q.hasPrefix("../") {
            return pathItems(q, prefix: "", foldersOnly: false, learn: q)
        }
        return []
    }

    /// Commandes perso, classées avec les apps.
    func customCommandItems(_ q: String, folded: String) -> [(Int, ResultItem)] {
        var out: [(Int, ResultItem)] = []
        for custom in AppSettings.shared.customCommands {
            let keyword = custom.keyword.lowercased()
            if custom.command.contains("{}"), !keyword.isEmpty, q.lowercased().hasPrefix(keyword + " ") {
                let arg = String(q.dropFirst(keyword.count + 1))
                out.append((1200, customItem(custom, argument: arg)))
                continue
            }
            let name = Fuzzy.fold(custom.name)
            let score = (!keyword.isEmpty && keyword.hasPrefix(folded)) ? 950 : Fuzzy.score(folded, name)
            if let score { out.append((score + Usage.boost("custom:" + custom.id.uuidString, query: q), customItem(custom, argument: nil))) }
        }
        return out
    }

    /// Historique shell proposé après les résultats quand on tape une commande sans « > ».
    func historyFallback(_ q: String) -> [ResultItem] {
        guard AppSettings.shared.shellCommands, Shell.isCommand(Shell.splitFirst(q).0) else { return [] }
        var out = [runItem(q)]
        for past in ShellHistory.search(q, limit: 4) where past != q {
            out.append(runItem(past, history: true))
        }
        return out
    }

    // MARK: Éléments

    func pathItems(_ raw: String, prefix: String, foldersOnly: Bool, learn: String) -> [ResultItem] {
        let path = Shell.expand(raw)
        var out: [ResultItem] = []
        let exists = FileManager.default.fileExists(atPath: path)
        let folder = Shell.isFolder(path)
        if exists && (!foldersOnly || folder) {
            let completion = prefix + Shell.abbreviate(path) + (folder && path != "/" ? "/" : "")
            out.append(pathItem(path, completion: completion, learn: learn))
        }
        for candidate in Shell.completions(raw, foldersOnly: foldersOnly)
        where candidate.lowercased() != path.lowercased() {
            let completion = prefix + Shell.abbreviate(candidate) + (Shell.isFolder(candidate) ? "/" : "")
            out.append(pathItem(candidate, completion: completion, learn: learn))
        }
        return out
    }

    /// Chemin du fichier désigné par un lien `file://` (collé depuis un terminal, un navigateur, Codex…),
    /// guillemets et chevrons autour tolérés, espaces non encodés aussi. nil si ce n'est pas un lien file://.
    static func fileURLPath(_ text: String) -> String? {
        let link = text.trimmingCharacters(in: CharacterSet(charactersIn: "'\"<>").union(.whitespacesAndNewlines))
        guard link.lowercased().hasPrefix("file://") else { return nil }
        let url = URL(string: link)
            ?? link.addingPercentEncoding(withAllowedCharacters: .urlFragmentAllowed).flatMap { URL(string: $0) }
        guard let url, url.isFileURL else { return nil }
        let path = url.standardizedFileURL.path
        return path.isEmpty ? nil : path
    }

    /// Lien file:// tapé ou collé : le fichier, ↵ l'ouvre avec l'app par défaut.
    func fileURLItems(_ q: String) -> [ResultItem]? {
        guard let path = Self.fileURLPath(q) else { return nil }
        if FileManager.default.fileExists(atPath: path) {
            var item = pathItem(path, completion: nil)
            item.section = "Lien vers un fichier"
            return [item]
        }
        let folder = (path as NSString).deletingLastPathComponent
        return [ResultItem(
            id: "missing:" + path, title: "Fichier introuvable", subtitle: Shell.abbreviate(path),
            icon: .symbol("questionmark.folder", .gray),
            primary: ItemAction(title: "Ouvrir le dossier") { [unowned self] in
                guard Shell.isFolder(folder) else { return flash("Le dossier n'existe pas non plus") }
                c.hide()
                NSWorkspace.shared.open(URL(fileURLWithPath: folder))
            })]
    }

    func pathItem(_ path: String, completion: String?, learn: String = "") -> ResultItem {
        let url = URL(fileURLWithPath: path)
        let folder = Shell.isFolder(path)
        let name = path == Shell.home ? "Dossier personnel" : FileManager.default.displayName(atPath: path)
        let branch = folder ? Git.branch(path) : nil
        let remember = { if folder { Usage.record("path:" + path, query: learn) } }
        return ResultItem(
            id: "path:" + path, title: name, subtitle: Shell.abbreviate(path), icon: .file(path),
            accessory: branch.map { "⎇ \($0)" } ?? (folder ? "Dossier" : "Fichier"),
            primary: ItemAction(title: folder ? "Ouvrir dans le Finder" : "Ouvrir") { [unowned self] in
                remember()
                c.hide()
                NSWorkspace.shared.open(url)
            },
            secondary: folder
                ? ItemAction(title: "Ouvrir dans \(Shell.terminal.name)") { [unowned self] in
                    remember()
                    c.hide()
                    Shell.open(url, with: Shell.terminal)
                }
                : ItemAction(title: "Afficher dans le Finder") { [unowned self] in
                    c.hide()
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                },
            tertiary: Shell.editor.map { editor in
                ItemAction(title: "Ouvrir dans \(editor.name)") { [unowned self] in
                    remember()
                    c.hide()
                    Shell.open(url, with: editor)
                }
            },
            completion: completion,
            copyText: path)
    }

    func runItem(_ command: String, history: Bool = false) -> ResultItem {
        ResultItem(
            id: (history ? "hist:" : "run:") + command, title: command,
            subtitle: history ? nil : "Exécuter dans zsh depuis ~",
            icon: .symbol(history ? "clock.arrow.circlepath" : "terminal", Color(white: 0.25)),
            accessory: history ? "Historique" : "Shell",
            primary: ItemAction(title: "Exécuter") { [unowned self] in startRun(command) },
            secondary: ItemAction(title: "Dans Terminal") { [unowned self] in
                ShellHistory.record(command)
                c.hide()
                Shell.runInTerminal(command)
            },
            completion: "> " + command,
            copyText: command)
    }

    private func customItem(_ custom: CustomCommand, argument: String?) -> ResultItem {
        let command = argument.map { custom.command.replacingOccurrences(of: "{}", with: $0) } ?? custom.command
        let needsArgument = argument == nil && custom.command.contains("{}")
        let usageID = "custom:" + custom.id.uuidString
        return ResultItem(
            id: "custom:\(custom.id)\(argument ?? "")",
            title: argument.map { "\(custom.name) : \($0)" } ?? custom.name,
            subtitle: needsArgument ? "Tape « \(custom.keyword) … » · \(custom.command)" : command,
            icon: .symbol("terminal.fill", .teal),
            accessory: custom.mode.title,
            primary: ItemAction(title: needsArgument ? "Compléter" : "Exécuter") { [unowned self] in
                if needsArgument {
                    setQuery(custom.keyword + " ")
                    return
                }
                Usage.record(usageID, query: query)
                switch custom.mode {
                case .app: startRun(command)
                case .terminal:
                    c.hide()
                    Shell.runInTerminal(command)
                case .silent: runSilently(command, name: custom.name)
                }
            },
            secondary: needsArgument ? nil : ItemAction(title: "Dans Terminal") { [unowned self] in
                c.hide()
                Shell.runInTerminal(command)
            },
            completion: needsArgument ? custom.keyword + " " : nil,
            copyText: command)
    }

    private func processItems(_ query: String) -> [ResultItem] {
        Processes.search(query).map { p in
            ResultItem(
                id: "proc:\(p.pid)", title: p.name, subtitle: "PID \(p.pid) · \(Shell.abbreviate(p.path))",
                icon: p.app?.bundleURL.map { ItemIcon.file($0.path) } ?? .symbol("gearshape.2", .gray),
                accessory: p.app != nil ? "App" : "Processus",
                primary: ItemAction(title: "Terminer") { [unowned self] in
                    flash(Processes.kill(p, force: false) ? "\(p.name) terminé" : "Impossible de terminer \(p.name)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refresh() }
                },
                secondary: ItemAction(title: "Forcer") { [unowned self] in
                    flash(Processes.kill(p, force: true) ? "\(p.name) tué" : "Impossible de tuer \(p.name)")
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.refresh() }
                },
                copyText: String(p.pid))
        }
    }

    private func portItems(_ filter: String) -> [ResultItem] {
        guard let ports = Ports.listening() else {
            return [ResultItem(id: "ports.loading", title: "Recherche des ports ouverts…", icon: .symbol("network", .blue),
                               primary: ItemAction(title: "Patienter") {})]
        }
        let wanted = Int(filter.trimmingCharacters(in: .whitespaces))
        let list = ports.filter { wanted == nil || $0.port == wanted }
        if list.isEmpty {
            return [ResultItem(id: "ports.none", title: wanted.map { "Rien n'écoute sur le port \($0)" } ?? "Aucun port en écoute",
                               icon: .symbol("network.slash", .gray), primary: ItemAction(title: "OK") {})]
        }
        return list.map { entry in
            let app = NSRunningApplication(processIdentifier: entry.pid)
            let process = ProcessEntry(pid: entry.pid, name: entry.command, path: entry.command, app: app)
            return ResultItem(
                id: "port:\(entry.pid):\(entry.port)", title: ":\(entry.port)  ·  \(app?.localizedName ?? entry.command)",
                subtitle: "PID \(entry.pid) · \(entry.address)",
                icon: app?.bundleURL.map { ItemIcon.file($0.path) } ?? .symbol("network", .blue),
                accessory: "Port",
                primary: ItemAction(title: "Ouvrir localhost") { [unowned self] in
                    c.hide()
                    if let url = URL(string: "http://localhost:\(entry.port)") { NSWorkspace.shared.open(url) }
                },
                secondary: ItemAction(title: "Arrêter le processus") { [unowned self] in
                    flash(Processes.kill(process, force: false) ? "Port \(entry.port) libéré" : "Impossible d'arrêter \(entry.command)")
                    Ports.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.refresh() }
                },
                tertiary: ItemAction(title: "Forcer") { [unowned self] in
                    Processes.kill(process, force: true)
                    Ports.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { self.refresh() }
                },
                copyText: "http://localhost:\(entry.port)")
        }
    }

    private func ipItems() -> [ResultItem] {
        var out = NetInfo.addresses().map { entry in
            ResultItem(id: "ip:" + entry.interface, title: entry.address, subtitle: "Adresse locale · \(entry.interface)",
                       icon: .symbol("network", .blue), accessory: "IP",
                       primary: ItemAction(title: "Copier") { [unowned self] in
                           Paster.copy(entry.address)
                           c.hide()
                       })
        }
        let host = ProcessInfo.processInfo.hostName
        out.append(ResultItem(id: "ip.host", title: host, subtitle: "Nom d'hôte", icon: .symbol("desktopcomputer", .gray),
                              primary: ItemAction(title: "Copier") { [unowned self] in
                                  Paster.copy(host)
                                  c.hide()
                              }))
        return out
    }
}

extension Shell {
    /// Sortie d'une commande passée par le shell de connexion (PATH utilisateur).
    static func capture(_ command: String) -> String {
        captureDirect("/bin/zsh", ["-l", "-c", command])
    }

    static func captureDirect(_ path: String, _ args: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = args
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return "" }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }
}
