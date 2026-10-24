import AppKit

/// Mises à jour depuis les releases GitHub de Hello : `Hello-<version>.zip` (ou le .dmg) de la release la plus récente.
/// La version de l'app est la clé `HelloVersion` de l'Info.plist, l'étiquette de la release est `v<version>`.
final class Updater: ObservableObject {
    static let shared = Updater()
    static let repo = "matthieuleconte1/Hello"

    struct Release: Equatable {
        let version: String
        let notes: String
        let asset: URL
        let page: URL
    }

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(Release)
        case downloading(Double)
        case installing
        case failed(String)
    }

    @Published private(set) var state: State = .idle {
        // La ligne « Mise à jour » de l'accueil suit l'état (disponible, téléchargement, installation).
        didSet { if state != oldValue { Controller.shared.model.refresh() } }
    }
    /// Release trouvée, gardée pendant le téléchargement et l'installation.
    private(set) var pending: Release?
    private var lastCheck = Date.distantPast
    private var progressWatch: NSKeyValueObservation?

    static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "HelloVersion") as? String
            ?? Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    var available: Release? {
        if case .available(let release) = state { return release }
        return nil
    }

    var busy: Bool {
        switch state {
        case .checking, .downloading, .installing: true
        default: false
        }
    }

    /// Vérification automatique : au lancement puis au plus une fois par jour, à l'ouverture du panneau.
    func checkIfDue() {
        guard AppSettings.shared.autoUpdateCheck, Date().timeIntervalSince(lastCheck) > 24 * 3600 else { return }
        switch state {
        case .checking, .downloading, .installing, .available: return
        default: check()
        }
    }

    func check() {
        lastCheck = Date()
        state = .checking
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases?per_page=15")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 20
        // Lu ici, sur le fil principal : la réponse arrive sur un fil de URLSession.
        let prereleases = AppSettings.shared.updatePrereleases
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            let result = Self.newest(data: data, prereleases: prereleases)
            DispatchQueue.main.async {
                guard let self else { return }
                if let error {
                    self.state = .failed(error.localizedDescription)
                } else if (response as? HTTPURLResponse)?.statusCode != 200 {
                    self.state = .failed("GitHub a répondu \((response as? HTTPURLResponse)?.statusCode ?? 0).")
                } else if let release = result, Self.compare(release.version, Self.currentVersion) > 0 {
                    self.pending = release
                    self.state = .available(release)
                } else {
                    self.state = .upToDate
                }
            }
        }.resume()
    }

    /// Release publiée la plus récente (préversions comprises si demandé) qui contient l'app.
    private static func newest(data: Data?, prereleases: Bool) -> Release? {
        guard let data, let list = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
        for release in list {
            guard release["draft"] as? Bool != true, prereleases || release["prerelease"] as? Bool != true,
                  let tag = release["tag_name"] as? String,
                  let page = (release["html_url"] as? String).flatMap(URL.init(string:)) else { continue }
            let assets = release["assets"] as? [[String: Any]] ?? []
            let url = { (ext: String) in
                assets.first { ($0["name"] as? String)?.hasSuffix(ext) == true }
                    .flatMap { $0["browser_download_url"] as? String }.flatMap(URL.init(string:))
            }
            guard let asset = url(".zip") ?? url(".dmg") else { continue }
            let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
            return Release(version: version, notes: release["body"] as? String ?? "", asset: asset, page: page)
        }
        return nil
    }

    /// Comparaison façon semver : 2.0.0 > 2.0.0-alpha.2 > 2.0.0-alpha.1 > 1.9.
    static func compare(_ a: String, _ b: String) -> Int {
        func split(_ v: String) -> ([Int], [String]) {
            // Étiquette vide ou réduite à un suffixe (« v », « -beta ») : pas de numéro, pas de plantage.
            let parts = v.split(separator: "-", maxSplits: 1, omittingEmptySubsequences: false).map(String.init)
            let numbers = (parts.first ?? "").split(separator: ".").map { Int($0) ?? 0 }
            let pre = parts.count > 1 ? parts[1].split(separator: ".").map(String.init) : []
            return (numbers, pre)
        }
        let (na, pa) = split(a), (nb, pb) = split(b)
        for i in 0..<max(na.count, nb.count) {
            let x = i < na.count ? na[i] : 0, y = i < nb.count ? nb[i] : 0
            if x != y { return x < y ? -1 : 1 }
        }
        // Sans suffixe, c'est la version finale : elle passe devant ses préversions.
        if pa.isEmpty || pb.isEmpty { return pa.isEmpty == pb.isEmpty ? 0 : (pa.isEmpty ? 1 : -1) }
        for i in 0..<max(pa.count, pb.count) {
            guard i < pa.count else { return -1 }
            guard i < pb.count else { return 1 }
            if pa[i] == pb[i] { continue }
            if let x = Int(pa[i]), let y = Int(pb[i]) { return x < y ? -1 : 1 }
            return pa[i] < pb[i] ? -1 : 1
        }
        return 0
    }

    // MARK: Installation

    /// Télécharge la release, vérifie que c'est bien Hello, remplace l'app puis la relance.
    func install() {
        guard !busy, let release = pending else { return }
        state = .downloading(0)
        let task = URLSession.shared.downloadTask(with: release.asset) { [weak self] file, _, error in
            guard let self else { return }
            DispatchQueue.main.async { self.progressWatch = nil }
            guard let file else {
                return DispatchQueue.main.async { self.state = .failed(error?.localizedDescription ?? "Téléchargement impossible.") }
            }
            // Le fichier temporaire disparaît au retour de ce bloc : on le garde ailleurs.
            let work = FileManager.default.temporaryDirectory.appendingPathComponent("Hello-update-\(UUID().uuidString)")
            try? FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let archive = work.appendingPathComponent(release.asset.lastPathComponent)
            try? FileManager.default.moveItem(at: file, to: archive)
            DispatchQueue.main.async { self.state = .installing }
            DispatchQueue.global(qos: .userInitiated).async {
                let result = Self.stage(archive, in: work)
                DispatchQueue.main.async {
                    switch result {
                    case .success(let app): self.swap(to: app)
                    case .failure(let error): self.state = .failed(error.message)
                    }
                }
            }
        }
        progressWatch = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            DispatchQueue.main.async {
                if case .downloading = self?.state { self?.state = .downloading(progress.fractionCompleted) }
            }
        }
        task.resume()
    }

    private struct UpdateError: Error { let message: String }

    /// Extrait Hello.app de l'archive (.zip ou .dmg) et vérifie son identité.
    private static func stage(_ archive: URL, in work: URL) -> Result<URL, UpdateError> {
        let out = work.appendingPathComponent("staged")
        try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        if archive.pathExtension == "zip" {
            guard run("/usr/bin/ditto", ["-x", "-k", archive.path, out.path]) else {
                return .failure(UpdateError(message: "Archive illisible."))
            }
        } else {
            let mount = work.appendingPathComponent("mount")
            guard run("/usr/bin/hdiutil", ["attach", "-nobrowse", "-readonly", "-mountpoint", mount.path, archive.path]) else {
                return .failure(UpdateError(message: "Image disque illisible."))
            }
            defer { _ = run("/usr/bin/hdiutil", ["detach", "-force", mount.path]) }
            guard run("/usr/bin/ditto", [mount.appendingPathComponent("Hello.app").path,
                                         out.appendingPathComponent("Hello.app").path]) else {
                return .failure(UpdateError(message: "Hello.app absent de l'image disque."))
            }
        }
        let app = out.appendingPathComponent("Hello.app")
        guard let bundle = Bundle(url: app), bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            return .failure(UpdateError(message: "L'archive ne contient pas Hello."))
        }
        return .success(app)
    }

    @discardableResult
    private static func run(_ tool: String, _ args: [String]) -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = args
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return false }
        process.waitUntilExit()
        return process.terminationStatus == 0
    }

    /// Un petit script attend la fin de Hello, remplace l'app (en gardant l'ancienne si la copie échoue) et la relance.
    private func swap(to app: URL) {
        let destination = Bundle.main.bundleURL.path
        // Dossier protégé (app installée par un autre compte) : le script échouerait après avoir quitté Hello,
        // qui se relancerait sans rien dire dans l'ancienne version.
        guard FileManager.default.isWritableFile(atPath: (destination as NSString).deletingLastPathComponent) else {
            state = .failed("Impossible de remplacer Hello dans ce dossier : installe la mise à jour à la main.")
            return
        }
        let script = """
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.2; done
        rm -rf "$DEST.old"
        if mv "$DEST" "$DEST.old" && /usr/bin/ditto "$NEW" "$DEST"; then rm -rf "$DEST.old"; \
        else rm -rf "$DEST"; mv "$DEST.old" "$DEST"; fi
        /usr/bin/xattr -dr com.apple.quarantine "$DEST" 2>/dev/null
        /usr/bin/open "$DEST"
        """
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", script]
        process.environment = ["DEST": destination, "NEW": app.path, "PATH": "/usr/bin:/bin"]
        do {
            try process.run()
            NSApp.terminate(nil)
        } catch {
            state = .failed(error.localizedDescription)
        }
    }
}

extension LauncherModel {
    /// En tête des suggestions quand une mise à jour attend (puis pendant son téléchargement).
    func updateItem() -> ResultItem? {
        let updater = Updater.shared
        guard let release = updater.pending else { return nil }
        let subtitle = switch updater.state {
        case .downloading(let progress): "Téléchargement… \(Int(progress * 100)) %"
        case .installing: "Installation… Hello va se relancer"
        case .failed(let message): "Échec : \(message) · ↵ pour réessayer"
        default: "Tu as la \(Updater.currentVersion) · ↵ installe et relance Hello"
        }
        return ResultItem(id: "update", section: "Mise à jour", title: "Hello \(release.version) est disponible",
                          subtitle: subtitle,
                          icon: .symbol("arrow.down.circle.fill", .green),
                          primary: ItemAction(title: "Installer") { Updater.shared.install() },
                          secondary: ItemAction(title: "Notes de version") { [unowned self] in
                              c.hide()
                              NSWorkspace.shared.open(release.page)
                          })
    }
}
