import AppKit
import SwiftUI

struct AppEntry {
    let id: String
    let name: String
    let path: String
    let key: String      // nom affiché (localisé), normalisé
    let altKey: String   // nom du bundle (souvent anglais), normalisé
    var detail: String?  // renseigné quand plusieurs apps portent le même nom : dossier + version
    /// Ni app système ni app Apple : lu une fois pendant le scan (hors du fil principal), pas à chaque affichage.
    var uninstallable = false

    func score(_ query: String) -> Int? {
        let a = Fuzzy.score(query, key)
        let b = Fuzzy.score(query, altKey).map { $0 - 5 }
        return [a, b].compactMap { $0 }.max()
    }
}

/// Index des applications : un simple scan de dossiers (quelques ms), refait au plus
/// une fois par minute et seulement à l'ouverture du panneau. Aucun watcher en tâche de fond.
final class AppIndex {
    private(set) var apps: [AppEntry] = []
    private var lastScan = Date.distantPast
    private var scanning = false

    func refresh() {
        guard !scanning else { return }
        scanning = true
        DispatchQueue.global(qos: .utility).async {
            let result = Self.scan()
            DispatchQueue.main.async {
                Self.warmGridIcons(result)
                self.apps = result
                self.lastScan = Date()
                self.scanning = false
                Controller.shared.model.appsDidChange()
            }
        }
    }

    func refreshIfStale() {
        if Date().timeIntervalSince(lastScan) > 60 { refresh() }
    }

    private static func scan() -> [AppEntry] {
        let fm = FileManager.default
        let home = NSHomeDirectory()
        let roots = [
            "/Applications",
            "/System/Applications",
            "\(home)/Applications",
            "/System/Library/CoreServices/Applications",
        ]
        var seen = Set<String>()
        var out: [AppEntry] = []

        func add(_ path: String) {
            guard seen.insert(path).inserted else { return }
            var display = fm.displayName(atPath: path)
            if display.hasSuffix(".app") { display = String(display.dropLast(4)) }
            let bundleName = ((path as NSString).lastPathComponent as NSString).deletingPathExtension
            let uninstallable = !path.hasPrefix("/System/")
                && Uninstaller.bundleID(path)?.hasPrefix("com.apple.") != true
            out.append(AppEntry(id: "app:" + path, name: display, path: path,
                                key: Fuzzy.fold(display), altKey: Fuzzy.fold(bundleName), uninstallable: uninstallable))
        }

        func visit(_ dir: String, depth: Int) {
            guard let names = try? fm.contentsOfDirectory(atPath: dir) else { return }
            for name in names where !name.hasPrefix(".") {
                let path = (dir as NSString).appendingPathComponent(name)
                if name.hasSuffix(".app") {
                    add(path)
                } else if depth < 2 {
                    var isDir: ObjCBool = false
                    if fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue {
                        visit(path, depth: depth + 1)
                    }
                }
            }
        }

        roots.forEach { visit($0, depth: 0) }
        add("/System/Library/CoreServices/Finder.app")
        // Plusieurs apps du même nom (ex. deux Chrome) : on affiche le dossier et la version de chacune.
        let counts = Dictionary(out.map { ($0.key, 1) }, uniquingKeysWith: +)
        for i in out.indices where counts[out[i].key, default: 0] > 1 {
            let folder = Shell.abbreviate((out[i].path as NSString).deletingLastPathComponent)
            let version = Bundle(path: out[i].path)?.infoDictionary?["CFBundleShortVersionString"] as? String
            out[i].detail = folder + (version.map { " · v\($0)" } ?? "")
        }
        return out.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// Grandes icônes de la première page de la grille préparées d'avance : la première ouverture
    /// des applications n'attend pas leur chargement (et ne redessine pas la grille en plein agrandissement).
    private static func warmGridIcons(_ apps: [AppEntry]) {
        IconCache.warm(apps.prefix(PanelLayout.maxAppsPerPage).map(\.path))
    }
}

enum Fuzzy {
    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    /// Score de correspondance (plus haut = meilleur), nil si pas de correspondance.
    /// `query` et `target` doivent déjà être normalisés avec `fold`.
    static func score(_ query: String, _ target: String) -> Int? {
        guard !query.isEmpty else { return 0 }
        if target == query { return 1000 }
        if target.hasPrefix(query) { return 900 - min(target.count - query.count, 50) }

        let words = target.split { $0 == " " || $0 == "-" || $0 == "_" || $0 == "." }
        if words.contains(where: { $0.hasPrefix(query) }) { return 800 - min(target.count, 50) }
        if query.count >= 2, String(words.compactMap(\.first)).hasPrefix(query) { return 750 }
        if target.contains(query) { return 600 - min(target.count, 50) }
        guard query.count >= 3 else { return nil }

        // Sous-séquence : "vsc" → "visual studio code"
        var score = 300
        var index = target.startIndex
        var previousWasAdjacent = false
        for ch in query {
            guard let found = target[index...].firstIndex(of: ch) else { return nil }
            if found == index && previousWasAdjacent {
                score += 12
            } else {
                score -= min(target.distance(from: index, to: found), 10)
            }
            previousWasAdjacent = true
            index = target.index(after: found)
        }
        return max(score, 1)
    }

    /// Tous les mots de la requête sont des préfixes de mots du texte.
    static func wordsMatch(_ query: String, _ text: String) -> Bool {
        let words = text.split(separator: " ")
        return query.split(separator: " ").allSatisfy { q in words.contains { $0.hasPrefix(q) } }
    }
}

enum IconCache {
    private static let cache = NSCache<NSString, NSImage>()

    /// Icône réduite à une seule représentation (celle d'AppKit la plus proche de 64 px) : l'icône brute en contient
    /// une trentaine, jusqu'à 1024 px, que SwiftUI réexaminerait pour chaque nouvelle ligne à chaque frappe.
    /// `large` : 240 px pour les grandes icônes de la grille d'applications.
    static func icon(_ path: String, large: Bool = false) -> NSImage {
        let key = cacheKey(path, large: large)
        if let cached = cache.object(forKey: key) { return cached }
        let source = NSWorkspace.shared.icon(forFile: path)
        let pixels: CGFloat = large ? 240 : 64
        var rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
        let image: NSImage
        if let cg = source.cgImage(forProposedRect: &rect, context: nil, hints: nil) {
            image = NSImage(cgImage: cg, size: NSSize(width: pixels / 2, height: pixels / 2))
        } else {
            source.size = NSSize(width: pixels, height: pixels)
            image = source
        }
        cache.setObject(image, forKey: key)
        return image
    }

    private static func cacheKey(_ path: String, large: Bool) -> NSString {
        (large ? "L:" : "") + path as NSString
    }

    static func cachedIcon(_ path: String, large: Bool) -> NSImage? {
        cache.object(forKey: cacheKey(path, large: large))
    }

    private static let loader = DispatchQueue(label: "hello.icons", qos: .userInitiated)
    private static let lock = NSLock()
    private static var generation = 0

    /// Charge les grandes icônes manquantes hors du fil principal, lot par lot (une page par lot),
    /// et prévient après chaque lot (avec son numéro de page). Un nouvel appel (nouvelle recherche) abandonne le précédent.
    static func preload(_ batches: [(page: Int, paths: [String])], onBatch: @escaping (Int) -> Void) {
        lock.lock()
        generation += 1
        let mine = generation
        lock.unlock()
        loader.async {
            for batch in batches {
                lock.lock()
                let stale = generation != mine
                lock.unlock()
                if stale { return }
                let missing = batch.paths.filter { cachedIcon($0, large: true) == nil }
                guard !missing.isEmpty else { continue }
                DispatchQueue.concurrentPerform(iterations: missing.count) { _ = icon(missing[$0], large: true) }
                DispatchQueue.main.async { onBatch(batch.page) }
            }
        }
    }

    private static var pending: [String: [(NSImage) -> Void]] = [:]

    /// Grande icône pour une case de la grille : tout de suite si elle est en cache, sinon chargée hors du fil
    /// principal (une seule fois même si plusieurs cases la demandent) et rendue sur le fil principal.
    static func requestLarge(_ path: String, done: @escaping (NSImage) -> Void) {
        if let cached = cachedIcon(path, large: true) { return done(cached) }
        lock.lock()
        let first = pending[path] == nil
        pending[path, default: []].append(done)
        lock.unlock()
        guard first else { return }
        loader.async {
            let image = icon(path, large: true)
            lock.lock()
            let callbacks = pending.removeValue(forKey: path) ?? []
            lock.unlock()
            DispatchQueue.main.async { callbacks.forEach { $0(image) } }
        }
    }

    /// Prépare en tâche de fond les grandes icônes qui manquent (sans prévenir personne : la grille les trouvera en cache).
    static func warm(_ paths: [String]) {
        DispatchQueue.global(qos: .utility).async {
            let missing = paths.filter { cachedIcon($0, large: true) == nil }
            DispatchQueue.concurrentPerform(iterations: missing.count) { _ = icon(missing[$0], large: true) }
        }
    }

    // MARK: Miniatures (images du presse-papiers)

    private static let thumbnails = DispatchQueue(label: "hello.thumbnails", qos: .userInitiated)

    private static func thumbnailKey(_ url: URL, _ pixels: Int) -> NSString {
        "thumb:\(pixels):" + url.path as NSString
    }

    static func cachedThumbnail(_ url: URL, pixels: Int) -> NSImage? {
        cache.object(forKey: thumbnailKey(url, pixels))
    }

    /// Miniature décodée par ImageIO à la taille voulue, hors du fil principal : une capture 5K n'est jamais
    /// décodée en entier pour une icône de 26 pt (ni gardée en mémoire à pleine taille).
    static func thumbnail(_ url: URL, pixels: Int, done: @escaping (NSImage?) -> Void) {
        if let cached = cachedThumbnail(url, pixels: pixels) { return done(cached) }
        thumbnails.async {
            var image: NSImage?
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
                kCGImageSourceThumbnailMaxPixelSize: pixels,
            ]
            if let source = CGImageSourceCreateWithURL(url as CFURL, nil),
               let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) {
                let scale = NSScreen.main?.backingScaleFactor ?? 2
                image = NSImage(cgImage: cg, size: NSSize(width: CGFloat(cg.width) / scale, height: CGFloat(cg.height) / scale))
                cache.setObject(image!, forKey: thumbnailKey(url, pixels))
            }
            DispatchQueue.main.async { done(image) }
        }
    }
}

/// Image du presse-papiers chargée en miniature, en arrière-plan (emplacement discret en attendant).
struct Thumbnail: View {
    let url: URL
    let pixels: Int
    var fill = false
    @StateObject private var loader = ThumbnailLoader()

    var body: some View {
        let image = loader.loaded?.url == url ? loader.loaded?.image : IconCache.cachedThumbnail(url, pixels: pixels)
        Group {
            if let image {
                Image(nsImage: image).resizable().aspectRatio(contentMode: fill ? .fill : .fit)
            } else {
                Image(systemName: "photo").foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onAppear { loader.load(url, pixels: pixels) }
        .onChange(of: url) { _, newURL in loader.load(newURL, pixels: pixels) }
    }
}

/// État de Thumbnail (@State n'est pas disponible sans Xcode complet).
final class ThumbnailLoader: ObservableObject {
    @Published private(set) var loaded: (url: URL, image: NSImage)?

    func load(_ url: URL, pixels: Int) {
        guard loaded?.url != url, IconCache.cachedThumbnail(url, pixels: pixels) == nil else { return }
        IconCache.thumbnail(url, pixels: pixels) { [weak self] image in
            if let image { self?.loaded = (url, image) }
        }
    }
}

/// Couleur dominante d'une icône d'app : la teinte la plus présente parmi les pixels colorés,
/// éclaircie pour bien ressortir sur le verre sombre. Calculée une fois par app (icône de 24 px).
enum IconColor {
    private static var cache: [String: NSColor] = [:]

    static func dominant(_ path: String) -> NSColor {
        if let cached = cache[path] { return cached }
        let color = compute(IconCache.icon(path)) ?? NSColor(srgbRed: 0.62, green: 0.5, blue: 1, alpha: 1)
        cache[path] = color
        return color
    }

    private static func compute(_ image: NSImage) -> NSColor? {
        var rect = NSRect(x: 0, y: 0, width: 64, height: 64)
        guard let cg = image.cgImage(forProposedRect: &rect, context: nil, hints: nil),
              let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        let side = 24
        var pixels = [UInt8](repeating: 0, count: side * side * 4)
        let drawn: Bool = pixels.withUnsafeMutableBytes { buffer in
            guard let ctx = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                      bytesPerRow: side * 4, space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            ctx.interpolationQuality = .medium
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        // 12 secteurs de teinte + 1 pour les gris ; chaque pixel pèse selon sa saturation et sa luminosité.
        let bins = 12
        var weight = [Double](repeating: 0, count: bins + 1)
        var sums = [(r: Double, g: Double, b: Double)](repeating: (0, 0, 0), count: bins + 1)
        for i in stride(from: 0, to: pixels.count, by: 4) {
            let a = Double(pixels[i + 3]) / 255
            guard a > 0.6 else { continue }
            let r = Double(pixels[i]) / 255 / a, g = Double(pixels[i + 1]) / 255 / a, b = Double(pixels[i + 2]) / 255 / a
            let hi = max(r, g, b), lo = min(r, g, b)
            let saturation = hi == 0 ? 0 : (hi - lo) / hi
            let bin: Int
            let w: Double
            if saturation < 0.22 || hi < 0.18 {
                bin = bins
                w = 0.08
            } else {
                var hue: Double
                if hi == r { hue = (g - b) / (hi - lo) } else if hi == g { hue = 2 + (b - r) / (hi - lo) } else { hue = 4 + (r - g) / (hi - lo) }
                hue = (hue < 0 ? hue + 6 : hue) / 6
                bin = min(Int(hue * Double(bins)), bins - 1)
                w = saturation * saturation * (0.35 + hi)
            }
            weight[bin] += w
            sums[bin].r += r * w
            sums[bin].g += g * w
            sums[bin].b += b * w
        }
        guard let best = weight.indices.max(by: { weight[$0] < weight[$1] }), weight[best] > 0 else { return nil }
        let mean = NSColor(srgbRed: sums[best].r / weight[best], green: sums[best].g / weight[best],
                           blue: sums[best].b / weight[best], alpha: 1)
        var h: CGFloat = 0, s: CGFloat = 0, v: CGFloat = 0
        mean.getHue(&h, saturation: &s, brightness: &v, alpha: nil)
        // Gris dominant (icône noire, blanche ou métal) : onde blanche ; sinon couleur vive et lumineuse.
        if best == bins { return NSColor(white: 0.92, alpha: 1) }
        return NSColor(hue: h, saturation: min(max(s, 0.55), 0.9), brightness: max(v, 0.9), alpha: 1)
    }
}
