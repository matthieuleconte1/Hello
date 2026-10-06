import AppKit

struct StoredColor: Codable, Identifiable {
    var id = UUID()
    let r: Double
    let g: Double
    let b: Double
    var date = Date()

    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
    private var bytes: (Int, Int, Int) { (Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded())) }

    var hex: String { String(format: "#%02X%02X%02X", bytes.0, bytes.1, bytes.2) }
    var rgb: String { "rgb(\(bytes.0), \(bytes.1), \(bytes.2))" }

    var hsl: String {
        let mx = max(r, g, b), mn = min(r, g, b), l = (mx + mn) / 2, d = mx - mn
        var h = 0.0, s = 0.0
        if d > 0 {
            s = l > 0.5 ? d / (2 - mx - mn) : d / (mx + mn)
            if mx == r { h = (g - b) / d + (g < b ? 6 : 0) }
            else if mx == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h *= 60
        }
        return "hsl(\(Int(h.rounded())), \(Int((s * 100).rounded()))%, \(Int((l * 100).rounded()))%)"
    }

    var formats: [ColorFormat] {
        [
            ColorFormat(name: "HEX", value: hex),
            ColorFormat(name: "RGB", value: rgb),
            ColorFormat(name: "HSL", value: hsl),
            ColorFormat(name: "SwiftUI", value: String(format: "Color(red: %.3f, green: %.3f, blue: %.3f)", r, g, b)),
            ColorFormat(name: "Tailwind", value: "[\(hex)]"),
        ]
    }
}

struct ColorFormat: Identifiable {
    let name: String
    let value: String
    var id: String { name }
}

final class ColorStore {
    private(set) var items: [StoredColor] = {
        guard let data = UserDefaults.standard.data(forKey: "colors"),
              let list = try? JSONDecoder().decode([StoredColor].self, from: data) else { return [] }
        return list
    }()

    @discardableResult
    func add(_ color: NSColor) -> StoredColor? {
        guard let c = color.usingColorSpace(.sRGB) else { return nil }
        let stored = StoredColor(r: Double(c.redComponent), g: Double(c.greenComponent), b: Double(c.blueComponent))
        items.removeAll { $0.hex == stored.hex }
        items.insert(stored, at: 0)
        if items.count > 40 { items.removeLast(items.count - 40) }
        save()
        return stored
    }

    func remove(_ color: StoredColor) {
        items.removeAll { $0.id == color.id }
        save()
    }

    private func save() {
        UserDefaults.standard.set(try? JSONEncoder().encode(items), forKey: "colors")
    }
}

/// Loupe native de macOS : aucune permission d'enregistrement d'écran nécessaire.
enum ColorPicker {
    private static var sampler: NSColorSampler?

    static func pick(_ done: @escaping (NSColor?) -> Void) {
        let s = NSColorSampler()
        sampler = s
        s.show { color in
            DispatchQueue.main.async {
                sampler = nil
                done(color)
            }
        }
    }
}

/// Réglages › Centre de contrôle › "Masquer automatiquement la barre des menus".
enum MenuBarMode: String, CaseIterable {
    case never, fullScreenOnly, desktopOnly, always

    var title: String {
        switch self {
        case .never: "Jamais"
        case .fullScreenOnly: "En plein écran uniquement"
        case .desktopOnly: "Sur le bureau uniquement"
        case .always: "Toujours"
        }
    }

    var detail: String {
        switch self {
        case .never: "La barre des menus reste toujours visible"
        case .fullScreenOnly: "Masquée seulement dans les apps en plein écran (réglage par défaut)"
        case .desktopOnly: "Masquée sur le bureau, visible en plein écran"
        case .always: "Toujours masquée, elle apparaît quand la souris touche le haut de l'écran"
        }
    }

    var symbol: String {
        switch self {
        case .never: "menubar.rectangle"
        case .fullScreenOnly: "arrow.up.left.and.arrow.down.right"
        case .desktopOnly: "menubar.dock.rectangle"
        case .always: "rectangle.dashed"
        }
    }

    private var hide: Bool { self == .always || self == .desktopOnly }
    private var visibleInFullScreen: Bool { self == .never || self == .desktopOnly }

    /// macOS 26+ : valeur du menu des Réglages (0 Toujours, 1 Sur le bureau, 2 En plein écran, 3 Jamais).
    private var systemOption: Int {
        switch self {
        case .always: 0
        case .desktopOnly: 1
        case .fullScreenOnly: 2
        case .never: 3
        }
    }

    private static let hideKey = "_HIHideMenuBar" as CFString
    private static let fullScreenKey = "AppleMenuBarVisibleInFullscreen" as CFString
    private static let optionKey = "AutoHideMenuBarOption" as CFString
    private static let controlCenter = "com.apple.controlcenter" as CFString

    static var current: MenuBarMode {
        CFPreferencesSynchronize(controlCenter, kCFPreferencesCurrentUser, kCFPreferencesAnyHost)
        if let option = CFPreferencesCopyValue(optionKey, controlCenter, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? Int,
           let mode = allCases.first(where: { $0.systemOption == option }) {
            return mode
        }
        CFPreferencesAppSynchronize(kCFPreferencesAnyApplication)
        let hide = CFPreferencesCopyAppValue(hideKey, kCFPreferencesAnyApplication) as? Bool ?? false
        let visible = CFPreferencesCopyAppValue(fullScreenKey, kCFPreferencesAnyApplication) as? Bool ?? false
        return allCases.first { $0.hide == hide && $0.visibleInFullScreen == visible } ?? .fullScreenOnly
    }

    /// Écrit exactement ce qu'écrivent les Réglages Système, puis prévient le Dock qui applique le changement.
    func apply() {
        let user = kCFPreferencesCurrentUser, host = kCFPreferencesAnyHost, global = kCFPreferencesAnyApplication
        CFPreferencesSetValue(Self.optionKey, NSNumber(value: systemOption), Self.controlCenter, user, host)
        CFPreferencesSynchronize(Self.controlCenter, user, host)
        CFPreferencesSetValue(Self.hideKey, NSNumber(value: hide), global, user, host)
        CFPreferencesSetValue(Self.fullScreenKey, NSNumber(value: visibleInFullScreen), global, user, host)
        CFPreferencesSynchronize(global, user, host)
        DistributedNotificationCenter.default().postNotificationName(
            NSNotification.Name("AppleInterfaceMenuBarHidingChangedNotification"),
            object: nil, userInfo: nil, deliverImmediately: true)

        // Ce qui applique réellement le masquage en direct : System Events (comme l'extension Raycast).
        // Première fois : macOS demande d'autoriser Hello à contrôler « System Events ».
        let script = "tell application \"System Events\" to set autohide menu bar of dock preferences to \(hide)"
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            try? process.run()
            process.waitUntilExit()
        }
    }
}
