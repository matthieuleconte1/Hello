import AppKit
import ImageIO
import UniformTypeIdentifiers

/// Pièce jointe donnée à Hermes : fichier du Mac, image collée ou capture d'écran.
struct Attachment: Identifiable, Hashable {
    let url: URL
    var isScreenshot = false
    /// Vignette calculée une fois (image réduite, ou icône du fichier) : rien n'est décodé pendant le rendu.
    let thumbnail: NSImage

    init(url: URL, isScreenshot: Bool = false) {
        self.url = url
        self.isScreenshot = isScreenshot
        thumbnail = Self.makeThumbnail(url) ?? NSWorkspace.shared.icon(forFile: url.path)
    }

    var id: String { url.path }
    var name: String { isScreenshot ? "Capture d'écran" : url.lastPathComponent }
    var isImage: Bool { UTType(filenameExtension: url.pathExtension)?.conforms(to: .image) ?? false }

    static func == (a: Attachment, b: Attachment) -> Bool { a.id == b.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    private static func makeThumbnail(_ url: URL) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageSourceCreateThumbnailFromImageAlways: true,
                                        kCGImageSourceThumbnailMaxPixelSize: 96,
                                        kCGImageSourceCreateThumbnailWithTransform: true]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
    }
}

enum Attachments {
    /// Captures et images collées. Vidé au lancement de Hello : une session du terminal peut encore s'en servir.
    static let folder = FileManager.default.temporaryDirectory.appendingPathComponent("Hello-attachments")

    static func cleanUp() {
        try? FileManager.default.removeItem(at: folder)
    }

    private static func newFile(_ prefix: String) -> URL {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let stamp = Int(Date().timeIntervalSince1970 * 1000)
        return folder.appendingPathComponent("\(prefix)-\(stamp).png")
    }

    /// Fichiers copiés dans le Finder, ou image sans fichier (capture copiée avec ⌃⇧⌘4, image d'une page web).
    static func fromPasteboard(_ pasteboard: NSPasteboard) -> [Attachment]? {
        if pasteboard.types?.contains(.fileURL) == true,
           let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           !urls.isEmpty {
            return urls.map { Attachment(url: $0) }
        }
        guard pasteboard.string(forType: .string) == nil, NSImage.canInit(with: pasteboard),
              let image = NSImage(pasteboard: pasteboard), let tiff = image.tiffRepresentation,
              let png = NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]) else { return nil }
        let url = newFile("Image")
        guard (try? png.write(to: url)) != nil else { return nil }
        return [Attachment(url: url)]
    }

    /// Hello peut-il voir l'écran ? Sinon on demande l'autorisation (une fois, ensuite Réglages Système).
    static func canCaptureScreen() -> Bool {
        if CGPreflightScreenCaptureAccess() { return true }
        CGRequestScreenCaptureAccess()
        return false
    }

    /// Capture interactive, comme ⌘⇧4 : zone à tracer, Espace pour une fenêtre, Échap pour annuler.
    static func captureScreen(_ done: @escaping (Attachment?) -> Void) {
        let url = newFile("Capture")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-i", "-x", url.path]
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                done(FileManager.default.fileExists(atPath: url.path) ? Attachment(url: url, isScreenshot: true) : nil)
            }
        }
        do { try process.run() } catch { done(nil) }
    }

    /// Capture d'une seule fenêtre, sans ombre, même si elle est en partie cachée.
    static func captureWindow(_ window: ScreenWindow, _ done: @escaping (Attachment?) -> Void) {
        let url = newFile("Fenetre")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", "-o", "-l\(window.id)", url.path]
        process.terminationHandler = { _ in
            DispatchQueue.main.async {
                done(FileManager.default.fileExists(atPath: url.path) ? Attachment(url: url, isScreenshot: true) : nil)
            }
        }
        do { try process.run() } catch { done(nil) }
    }

    static func pickFiles(_ done: @escaping ([Attachment]) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.prompt = "Joindre"
        panel.message = "Fichiers ou dossiers à donner à \(AgentEngine.assistant.name)"
        NSApp.activate(ignoringOtherApps: true)
        panel.begin { response in
            done(response == .OK ? panel.urls.map { Attachment(url: $0) } : [])
        }
    }
}

/// Une fenêtre visible à l'écran. Le titre n'est donné par macOS qu'avec l'autorisation d'enregistrement de l'écran.
struct ScreenWindow: Hashable {
    let id: CGWindowID
    let pid: pid_t
    let app: String
    let title: String?

    var label: String { title.map { "\(app) — \($0)" } ?? app }

    /// Fenêtres normales à l'écran, de l'avant vers l'arrière, sans celles de Hello ni les petits éléments
    /// (barre des menus, Dock, bulles).
    static func visible(limit: Int = 15) -> [ScreenWindow] {
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return [] }
        let me = ProcessInfo.processInfo.processIdentifier
        let windows: [ScreenWindow] = list.compactMap { info in
            guard info[kCGWindowLayer as String] as? Int == 0,
                  info[kCGWindowOwnerPID as String] as? Int32 != me,
                  let id = info[kCGWindowNumber as String] as? CGWindowID,
                  let app = info[kCGWindowOwnerName as String] as? String,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  let bounds = info[kCGWindowBounds as String] as? [String: CGFloat],
                  (bounds["Width"] ?? 0) >= 80, (bounds["Height"] ?? 0) >= 60 else { return nil }
            let title = (info[kCGWindowName as String] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return ScreenWindow(id: id, pid: pid, app: app, title: title)
        }
        return Array(windows.prefix(limit))
    }
}

/// Élément de menu AppKit qui appelle une closure.
final class ClosureMenuItem: NSMenuItem {
    private let handler: () -> Void

    init(_ title: String, key: String = "", handler: @escaping () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: key)
        target = self
        if !key.isEmpty { keyEquivalentModifierMask = [.command, .shift] }
    }

    required init(coder: NSCoder) { fatalError("init(coder:) non utilisé") }

    @objc private func run() { handler() }
}

/// Ce que Hermes sait de la situation au moment de la demande.
struct MacContext {
    let frontmostApp: String?
    let attachments: [Attachment]
    /// Fenêtres à l'écran au moment de la demande (vide si le réglage est coupé).
    let windows: [ScreenWindow]
    /// Hello peut-il capturer l'écran (et donc l'IA, lancée par lui) ?
    let canCapture: Bool
    /// Hello a-t-il l'accessibilité ? Les commandes de l'IA en héritent (System Events).
    let accessibility: Bool
    /// Échanges précédents de la conversation (question de suite), vide pour une première demande.
    let history: String

    /// Le panneau de Hello n'active pas l'app : celle au premier plan est celle où l'on travaillait.
    init(attachments: [Attachment], history: String = "") {
        self.history = history
        let app = NSWorkspace.shared.frontmostApplication
        frontmostApp = app.flatMap { $0.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : $0.localizedName }
            .map { name in app?.bundleIdentifier.map { "\(name) (\($0))" } ?? name }
        self.attachments = attachments
        canCapture = CGPreflightScreenCaptureAccess()
        accessibility = AXIsProcessTrusted()
        windows = AppSettings.shared.agentWindows ? ScreenWindow.visible() : []
    }

    var firstImage: Attachment? { attachments.first(where: \.isImage) }

    /// Bloc ajouté aux prompts. Vide s'il n'y a rien à dire.
    var block: String {
        var lines: [String] = []
        let version = ProcessInfo.processInfo.operatingSystemVersion
        lines.append("- macOS \(version.majorVersion).\(version.minorVersion), user home: \(Shell.home)")
        if let frontmostApp { lines.append("- Frontmost app when the user asked: \(frontmostApp)") }
        if !accessibility {
            lines.append("- Hello (which runs your commands) lacks the Accessibility permission: System Events keystrokes, "
                         + "clicks and menu actions will be refused, so do not try them. Use other ways, or tell the user to "
                         + "allow it in Hello › Réglages › Agent.")
        }
        if !attachments.isEmpty {
            lines.append("- Files attached by the user (local paths; look at images with vision_analyze, read others with read_file):")
            for attachment in attachments {
                let kind = attachment.isScreenshot ? "screenshot of the user's screen"
                    : attachment.isImage ? "image" : Shell.isFolder(attachment.url.path) ? "folder" : "file"
                lines.append("  - \(attachment.url.path) (\(kind))")
            }
        }
        if !windows.isEmpty {
            lines.append("- Windows open on screen, front to back (window id, app — title):")
            for window in windows { lines.append("  - [\(window.id)] \(window.label)") }
            lines.append(canCapture
                ? "  To see one of them only when the request needs it: `screencapture -x -o -l<window id> /tmp/hello-window.png`, then look at the image."
                : "  (Window titles and screenshots are unavailable: Hello lacks the Screen Recording permission.)")
        }
        var block = "Context from Hello:\n" + lines.joined(separator: "\n")
        if !history.isEmpty {
            block += "\n\nThis is a follow-up. Earlier in this conversation (oldest first):\n" + history
        }
        return block
    }

    /// Pour le routeur, qui n'a aucun outil et ne voit pas les fichiers.
    var routerNote: String {
        guard !attachments.isEmpty else { return block }
        return block + "\nYou cannot see the attachments: if the request depends on their content, never use ANSWER."
    }
}

extension LauncherModel {
    func attach(_ new: [Attachment]) {
        let fresh = new.filter { item in !attachments.contains(item) }
        guard !fresh.isEmpty else { return }
        setAttachments(attachments + fresh)
        selection = 0
        refresh()
    }

    func detach(_ attachment: Attachment) {
        setAttachments(attachments.filter { $0 != attachment })
        refresh()
    }

    /// Capture d'écran pour Hermes : Hello s'efface le temps de tracer la zone, puis revient tel qu'il était.
    func captureForAgent() {
        guard Hermes.available, Attachments.canCaptureScreen() else {
            if Hermes.available { flash("Autorise Hello dans Réglages Système › Enregistrement de l'écran") }
            return
        }
        stepAside { back in
            // Le temps que le panneau disparaisse de l'écran avant le début de la capture.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                Attachments.captureScreen { back($0.map { [$0] } ?? []) }
            }
        }
    }

    /// Menu du bouton appareil photo, sous la souris : une zone à tracer, ou une des fenêtres à l'écran
    /// (lues au moment du clic).
    func showCaptureMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.addItem(ClosureMenuItem("Zone ou fenêtre à tracer…", key: "s") { [weak self] in self?.captureForAgent() })
        let windows = ScreenWindow.visible()
        if !windows.isEmpty {
            menu.addItem(.separator())
            menu.addItem(.sectionHeader(title: CGPreflightScreenCaptureAccess() ? "Fenêtres à l'écran"
                                                                                : "Fenêtres (autorisation requise)"))
            for window in windows {
                let item = ClosureMenuItem(window.label) { [weak self] in self?.captureWindowForAgent(window) }
                if let app = NSRunningApplication(processIdentifier: window.pid) {
                    let icon = app.icon?.copy() as? NSImage
                    icon?.size = NSSize(width: 16, height: 16)
                    item.image = icon
                }
                menu.addItem(item)
            }
        }
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    /// Capture d'une des fenêtres à l'écran, jointe à la demande. Le panneau reste ouvert.
    func captureWindowForAgent(_ window: ScreenWindow) {
        guard Hermes.available, Attachments.canCaptureScreen() else {
            if Hermes.available { flash("Autorise Hello dans Réglages Système › Enregistrement de l'écran") }
            return
        }
        Attachments.captureWindow(window) { [weak self] attachment in
            if let attachment { self?.attach([attachment]) } else { self?.flash("Capture de la fenêtre impossible") }
        }
    }

    func pickFilesForAgent() {
        guard Hermes.available else { return }
        stepAside { back in Attachments.pickFiles(back) }
    }

    /// Fichiers glissés sur le panneau (ouvre Hello pendant le glisser, puis lâche dessus).
    func dropFiles(_ providers: [NSItemProvider]) -> Bool {
        guard Hermes.available, mode == .root else { return false }
        for provider in providers {
            _ = provider.loadObject(ofClass: URL.self) { [weak self] url, _ in
                guard let url, url.isFileURL else { return }
                DispatchQueue.main.async { self?.attach([Attachment(url: url)]) }
            }
        }
        return true
    }

    /// Ferme le panneau, laisse `work` faire (capture, sélecteur de fichiers), puis le rouvre avec le texte
    /// et les pièces jointes d'avant, plus les nouvelles.
    private func stepAside(_ work: (@escaping ([Attachment]) -> Void) -> Void) {
        let text = query
        let kept = attachments
        c.hide()
        work { [weak self] added in
            guard let self else { return }
            c.show()
            setAttachments(kept)
            attach(added)
            setQuery(text)
        }
    }
}
