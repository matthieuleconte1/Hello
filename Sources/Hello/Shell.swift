import AppKit

/// Tout ce qui touche au "mode terminal" : chemins, complétion, exécution.
enum Shell {
    static let home = NSHomeDirectory()

    private static var pathDirs: [String] =
        (ProcessInfo.processInfo.environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin")
            .split(separator: ":").map(String.init) + ["/opt/homebrew/bin", "/usr/local/bin"]
    private static var commandCache: [String: Bool] = [:]
    static var userPath: String { pathDirs.joined(separator: ":") }
    private static let builtins: Set<String> = [
        "cd", "echo", "export", "source", "alias", "which", "type", "print", "eval", "exec",
        "kill", "time", "for", "while", "if", "pushd", "popd", "history", "unset", "set",
    ]
    private static let operators = ["&&", "||", ";", "|", ">", "<", "`", "$("]

    /// Récupère le PATH du shell de connexion (Homebrew, etc.) une seule fois au lancement.
    static func loadUserPath() {
        DispatchQueue.global(qos: .utility).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/zsh")
            process.arguments = ["-l", "-c", "print -r -- $PATH"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return }
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let line = String(decoding: data, as: UTF8.self)
                .split(separator: "\n").last.map(String.init) ?? ""
            guard line.contains("/") else { return }
            DispatchQueue.main.async {
                pathDirs = line.split(separator: ":").map(String.init)
                commandCache = [:]
            }
        }
    }

    static func splitFirst(_ s: String) -> (String, String) {
        guard let space = s.firstIndex(of: " ") else { return (s, "") }
        return (String(s[..<space]), s[s.index(after: space)...].trimmingCharacters(in: .whitespaces))
    }

    static func hasOperators(_ s: String) -> Bool {
        operators.contains { s.contains($0) }
    }

    static func isCommand(_ word: String) -> Bool {
        guard !word.isEmpty else { return false }
        if builtins.contains(word) { return true }
        if let cached = commandCache[word] { return cached }
        let fm = FileManager.default
        let found = word.contains("/")
            ? fm.isExecutableFile(atPath: expand(word))
            : pathDirs.contains { fm.isExecutableFile(atPath: ($0 as NSString).appendingPathComponent(word)) }
        commandCache[word] = found
        return found
    }

    /// `./code`, `code`, `~/code` → /Users/…/code  (le dossier courant est le dossier personnel)
    static func expand(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespaces)
        if s.count >= 2, let first = s.first, first == "\"" || first == "'", s.last == first {
            s = String(s.dropFirst().dropLast())
        }
        s = s.replacingOccurrences(of: "\\ ", with: " ")
        if s.isEmpty || s == "~" { return home }
        if s.hasPrefix("~/") {
            s = home + s.dropFirst()
        } else if !s.hasPrefix("/") {
            s = home + "/" + s
        }
        return (s as NSString).standardizingPath
    }

    static func abbreviate(_ path: String) -> String {
        if path == home { return "~" }
        if path.hasPrefix(home + "/") { return "~" + path.dropFirst(home.count) }
        return path
    }

    static func isFolder(_ path: String) -> Bool {
        var isDir: ObjCBool = false
        return FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            && isDir.boolValue && !NSWorkspace.shared.isFilePackage(atPath: path)
    }

    /// Complétion façon Tab : liste les entrées du dossier parent qui correspondent.
    static func completions(_ raw: String, foldersOnly: Bool, limit: Int = 8) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespaces)
        let full = expand(trimmed)
        let listing = trimmed.isEmpty || trimmed == "~" || trimmed.hasSuffix("/")
        let dir = listing ? full : (full as NSString).deletingLastPathComponent
        let partial = listing ? "" : Fuzzy.fold((full as NSString).lastPathComponent)

        guard let names = try? FileManager.default.contentsOfDirectory(atPath: dir) else { return [] }
        var matches: [(Int, String)] = []
        for name in names {
            if name.hasPrefix(".") && !partial.hasPrefix(".") { continue }
            let folded = Fuzzy.fold(name)
            let rank: Int
            if partial.isEmpty { rank = 0 }
            else if folded.hasPrefix(partial) { rank = 2 }
            else if folded.contains(partial) { rank = 1 }
            else { continue }
            let path = (dir as NSString).appendingPathComponent(name)
            if foldersOnly && !isFolder(path) { continue }
            matches.append((rank, path))
        }
        matches.sort {
            $0.0 != $1.0 ? $0.0 > $1.0 : $0.1.localizedStandardCompare($1.1) == .orderedAscending
        }
        return matches.prefix(limit).map(\.1)
    }

    // MARK: - Apps externes

    struct AppRef {
        let name: String
        let url: URL
    }

    static func app(_ bundleID: String) -> AppRef? {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else { return nil }
        var name = FileManager.default.displayName(atPath: url.path)
        if name.hasSuffix(".app") { name = String(name.dropLast(4)) }
        return AppRef(name: name, url: url)
    }

    private static let autoTerminal: AppRef =
        ExternalApps.terminals.map(\.id).lazy.compactMap(app).first
            ?? AppRef(name: "Terminal", url: URL(fileURLWithPath: "/System/Applications/Utilities/Terminal.app"))
    private static let autoEditor: AppRef? = ExternalApps.editors.map(\.id).lazy.compactMap(app).first

    /// Terminal choisi dans les réglages (ou le premier installé).
    static var terminal: AppRef {
        let id = AppSettings.shared.terminalID
        return id.isEmpty ? autoTerminal : app(id) ?? autoTerminal
    }

    /// Éditeur choisi dans les réglages ("none" = désactivé).
    static var editor: AppRef? {
        let id = AppSettings.shared.editorID
        if id == "none" { return nil }
        return id.isEmpty ? autoEditor : app(id) ?? autoEditor
    }

    static func open(_ url: URL, with app: AppRef) {
        NSWorkspace.shared.open([url], withApplicationAt: app.url, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Lance la commande dans le terminal choisi (Réglages), dans `directory`, puis laisse un shell ouvert.
    /// Ghostty et iTerm sont pilotés en AppleScript (une seule autorisation « Hello peut contrôler… »),
    /// les autres reçoivent un script .command temporaire qui s'efface lui-même.
    static func runInTerminal(_ command: String, in directory: String = home) {
        let target = terminal
        let bundleID = Bundle(url: target.url)?.bundleIdentifier ?? ""
        let wrapped = "/bin/zsh -lic " + singleQuoted(command + "; exec /bin/zsh -l")
        switch bundleID {
        case "com.mitchellh.ghostty":
            osascript([
                "on run argv",
                "tell application id \"com.mitchellh.ghostty\"",
                "activate",
                "new window with configuration {initial working directory:(item 1 of argv), command:(item 2 of argv)}",
                "end tell",
                "end run",
            ], args: [directory, wrapped], fallback: { runScript(command, in: directory, with: target) })
        case "com.googlecode.iterm2":
            osascript([
                "on run argv",
                "tell application id \"com.googlecode.iterm2\"",
                "activate",
                "set w to (create window with default profile)",
                "tell current session of w to write text (\"cd \" & quoted form of (item 1 of argv) & \" && \" & (item 2 of argv))",
                "end tell",
                "end run",
            ], args: [directory, command], fallback: { runScript(command, in: directory, with: target) })
        default:
            runScript(command, in: directory, with: target)
        }
    }

    static func singleQuoted(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private static func osascript(_ lines: [String], args: [String], fallback: @escaping () -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = lines.flatMap { ["-e", $0] } + args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            guard (try? process.run()) != nil else { return DispatchQueue.main.async(execute: fallback) }
            process.waitUntilExit()
            // Autorisation refusée ou version sans AppleScript : on retombe sur le script .command.
            if process.terminationStatus != 0 { DispatchQueue.main.async(execute: fallback) }
        }
    }

    private static func runScript(_ command: String, in directory: String, with target: AppRef) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("HelloScripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("hello-\(UUID().uuidString.prefix(8)).command")
        let script = "#!/bin/zsh -l\ncd \(singleQuoted(directory)) 2>/dev/null || cd ~\nrm -f -- \"$0\"\n\(command)\nexec zsh -l\n"
        do {
            try script.write(to: file, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: file.path)
        } catch {
            NSSound.beep()
            return
        }
        let bundleID = Bundle(url: target.url)?.bundleIdentifier ?? ""
        switch bundleID {
        case "net.kovidgoyal.kitty", "io.alacritty":
            let config = NSWorkspace.OpenConfiguration()
            config.createsNewApplicationInstance = true
            config.arguments = bundleID == "io.alacritty" ? ["-e", file.path] : [file.path]
            NSWorkspace.shared.openApplication(at: target.url, configuration: config)
        case "dev.warp.Warp-Stable":
            let configs = URL(fileURLWithPath: home + "/.warp/launch_configurations", isDirectory: true)
            try? FileManager.default.createDirectory(at: configs, withIntermediateDirectories: true)
            let name = "hello-run.yaml"
            let yaml = "---\nname: Hello\nwindows:\n  - tabs:\n      - layout:\n          cwd: \(directory)\n"
                + "          commands:\n            - exec: \(file.path)\n"
            try? yaml.write(to: configs.appendingPathComponent(name), atomically: true, encoding: .utf8)
            if let url = URL(string: "warp://launch/\(name)") { NSWorkspace.shared.open(url) }
        default:
            open(file, with: target)
        }
    }
}

/// Exécution d'une commande dans zsh, dans un pseudo-terminal (PTY) : les outils se croient
/// dans un vrai terminal et gardent leurs couleurs, affichées en direct dans Hello.
final class ShellRun: ObservableObject {
    let command: String
    @Published private(set) var rendered = AttributedString()
    @Published private(set) var running = false
    @Published private(set) var status: Int32?
    private(set) var startedAt = Date()
    private(set) var finishedAt: Date?
    var onFinish: ((Int32) -> Void)?
    private var process: Process?
    private var reader: DispatchSourceRead?
    private let buffer = TerminalBuffer()
    private var renderScheduled = false
    private var received = 0
    private static let maxOutput = 2_000_000

    var output: String { buffer.plainText }
    var isEmpty: Bool { buffer.isEmpty }

    var elapsed: String {
        let seconds = (finishedAt ?? Date()).timeIntervalSince(startedAt)
        return seconds < 60 ? String(format: "%.1f s", seconds) : String(format: "%d min %02d s", Int(seconds) / 60, Int(seconds) % 60)
    }

    init(command: String) {
        self.command = command
    }

    func start() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Mode interactif (-i) : charge ~/.zshrc, donc alias et fonctions perso.
        process.arguments = AppSettings.shared.shellInteractive ? ["-l", "-i", "-c", command] : ["-l", "-c", command]
        process.currentDirectoryURL = URL(fileURLWithPath: Shell.home)

        // Largeur du terminal calée sur celle du panneau (police mono 12 pt ≈ 7,25 pt par colonne).
        let columns = UInt16(max(60, (PanelLayout.size.width - 40) / 7.25))
        var env = ProcessInfo.processInfo.environment
        env.removeValue(forKey: "NO_COLOR")
        env["TERM"] = "xterm-256color"
        env["COLORTERM"] = "truecolor"
        env["CLICOLOR"] = "1"
        env["FORCE_COLOR"] = "1"
        env["COLUMNS"] = String(columns)
        env["PAGER"] = "cat"
        env["GIT_PAGER"] = "cat"
        process.environment = env

        var master: Int32 = -1, slave: Int32 = -1
        var size = winsize(ws_row: 40, ws_col: columns, ws_xpixel: 0, ws_ypixel: 0)
        if openpty(&master, &slave, nil, nil, &size) == 0 {
            let slaveHandle = FileHandle(fileDescriptor: slave, closeOnDealloc: true)
            process.standardInput = slaveHandle
            process.standardOutput = slaveHandle
            process.standardError = slaveHandle
            listen(on: master)
        } else {
            // Repli sans PTY : couleurs forcées quand l'outil le permet.
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            process.standardInput = FileHandle.nullDevice
            listen(on: pipe.fileHandleForReading.fileDescriptor)
        }

        process.terminationHandler = { [weak self] p in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                guard let self else { return }
                self.render()
                self.running = false
                self.finishedAt = Date()
                self.status = p.terminationStatus
                self.onFinish?(p.terminationStatus)
            }
        }
        do {
            startedAt = Date()
            try process.run()
            running = true
            self.process = process
            // Le parent ferme sa copie de l'esclave : la lecture s'arrête quand le processus se termine.
            if slave >= 0 { (process.standardOutput as? FileHandle)?.closeFile() }
        } catch {
            buffer.feed(error.localizedDescription)
            render()
            status = -1
        }
    }

    /// Lecture non bloquante du descripteur (évite les exceptions de FileHandle sur un PTY fermé).
    private func listen(on fd: Int32) {
        let source = DispatchSource.makeReadSource(fileDescriptor: fd, queue: .global(qos: .userInitiated))
        // Caractère UTF-8 coupé entre deux lectures (accent, emoji, trait de tableau) : gardé pour la suivante,
        // sinon il s'afficherait en « � ». Le gestionnaire d'une même source n'est jamais exécuté en parallèle.
        var pending: [UInt8] = []
        source.setEventHandler { [weak self] in
            var bytes = [UInt8](repeating: 0, count: 65_536)
            let count = read(fd, &bytes, bytes.count)
            guard count > 0 else {
                if !pending.isEmpty {
                    let rest = String(decoding: pending, as: UTF8.self)
                    pending = []
                    DispatchQueue.main.async { self?.append(rest, bytes: rest.utf8.count) }
                }
                source.cancel()
                return
            }
            var chunk = pending + bytes[0..<count]
            let cut = Self.incompleteTail(chunk)
            pending = Array(chunk.suffix(cut))
            chunk.removeLast(cut)
            let text = String(decoding: chunk, as: UTF8.self)
            DispatchQueue.main.async { self?.append(text, bytes: count) }
        }
        source.setCancelHandler { close(fd) }
        source.resume()
        reader = source
    }

    /// Nombre d'octets en fin de tampon qui commencent un caractère UTF-8 pas encore complet.
    private static func incompleteTail(_ bytes: [UInt8]) -> Int {
        var back = 0
        for byte in bytes.reversed() {
            back += 1
            if byte & 0xC0 != 0x80 {
                let length = byte >= 0xF0 ? 4 : byte >= 0xE0 ? 3 : byte >= 0xC0 ? 2 : 1
                return length > back ? back : 0
            }
            if back == 4 { return 0 }
        }
        return 0
    }

    func cancel() {
        guard running, let process else { return }
        process.interrupt()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
            if self?.running == true { process.terminate() }
        }
    }

    private func append(_ text: String, bytes: Int) {
        guard received < Self.maxOutput else { return }
        received += bytes
        buffer.feed(text)
        // Rendu regroupé (~20 fois par seconde max) pour rester léger sur les grosses sorties.
        guard !renderScheduled else { return }
        renderScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in self?.render() }
    }

    private func render() {
        renderScheduled = false
        rendered = buffer.attributed(fontSize: 12)
    }
}
