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

/// Ce que Hermes sait de la situation au moment de la demande.
struct MacContext {
    let frontmostApp: String?
    let attachments: [Attachment]
    /// Échanges précédents de la conversation (question de suite), vide pour une première demande.
    let history: String

    /// Le panneau de Hello n'active pas l'app : celle au premier plan est celle où l'on travaillait.
    init(attachments: [Attachment], history: String = "") {
        self.history = history
        let app = NSWorkspace.shared.frontmostApplication
        frontmostApp = app.flatMap { $0.bundleIdentifier == Bundle.main.bundleIdentifier ? nil : $0.localizedName }
            .map { name in app?.bundleIdentifier.map { "\(name) (\($0))" } ?? name }
        self.attachments = attachments
    }

    var firstImage: Attachment? { attachments.first(where: \.isImage) }

    /// Bloc ajouté aux prompts. Vide s'il n'y a rien à dire.
    var block: String {
        var lines: [String] = []
        let version = ProcessInfo.processInfo.operatingSystemVersion
        lines.append("- macOS \(version.majorVersion).\(version.minorVersion), user home: \(Shell.home)")
        if let frontmostApp { lines.append("- Frontmost app when the user asked: \(frontmostApp)") }
        if !attachments.isEmpty {
            lines.append("- Files attached by the user (local paths; look at images with vision_analyze, read others with read_file):")
            for attachment in attachments {
                let kind = attachment.isScreenshot ? "screenshot of the user's screen"
                    : attachment.isImage ? "image" : Shell.isFolder(attachment.url.path) ? "folder" : "file"
                lines.append("  - \(attachment.url.path) (\(kind))")
            }
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
