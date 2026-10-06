import AppKit
import SwiftUI

enum PanelSize: String, CaseIterable, Identifiable {
    case compact, standard, large
    var id: String { rawValue }

    var title: String {
        switch self {
        case .compact: "Compact"
        case .standard: "Standard"
        case .large: "Grand"
        }
    }

    var size: CGSize {
        switch self {
        case .compact: CGSize(width: 680, height: 420)
        case .standard: CGSize(width: 760, height: 480)
        case .large: CGSize(width: 880, height: 560)
        }
    }

    var gridColumns: Int {
        switch self {
        case .compact: 10
        case .standard: 11
        case .large: 13
        }
    }
}

enum MotionIntensity: String, CaseIterable, Identifiable {
    case subtle, normal, expressive
    var id: String { rawValue }
    var title: String {
        switch self {
        case .subtle: "Subtiles"
        case .normal: "Normales"
        case .expressive: "Expressives"
        }
    }
    /// Amplitude des mouvements (décalages, échelles, rotations).
    var amplitude: CGFloat {
        switch self {
        case .subtle: 0.45
        case .normal: 1
        case .expressive: 1.6
        }
    }
}

enum RowDensity: String, CaseIterable, Identifiable {
    case compact, standard, comfortable
    var id: String { rawValue }
    var title: String {
        switch self {
        case .compact: "Compacte"
        case .standard: "Standard"
        case .comfortable: "Aérée"
        }
    }
    var rowHeight: CGFloat {
        switch self {
        case .compact: 36
        case .standard: 44
        case .comfortable: 52
        }
    }
    var iconSize: CGFloat {
        switch self {
        case .compact: 22
        case .standard: 26
        case .comfortable: 30
        }
    }
}

enum ThemeAppearance: String, CaseIterable, Identifiable {
    case auto, light, dark
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .light: "Clair"
        case .dark: "Sombre"
        }
    }
}

/// Formes Material 3 Expressive des pastilles d'Atelier : cercle au repos, la forme choisie une fois sélectionnée.
enum AtelierShape: String, CaseIterable, Identifiable {
    case cookie, clover, flower, sunny, circle
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cookie: "Cookie"
        case .clover: "Trèfle"
        case .flower: "Fleur"
        case .sunny: "Soleil"
        case .circle: "Cercle"
        }
    }
    var lobes: Int {
        switch self {
        case .cookie: 9
        case .clover: 4
        case .flower: 6
        case .sunny: 12
        case .circle: 1
        }
    }
    var depth: CGFloat {
        switch self {
        case .cookie: 0.16
        case .clover: 0.4
        case .flower: 0.28
        case .sunny: 0.1
        case .circle: 0
        }
    }
}

enum PhosphorColor: String, CaseIterable, Identifiable {
    case green, amber, white, cyan
    var id: String { rawValue }
    var title: String {
        switch self {
        case .green: "Vert P1"
        case .amber: "Ambre P3"
        case .white: "Blanc P4"
        case .cyan: "Cyan"
        }
    }
    var colors: (ink: Color, screen: Color) {
        switch self {
        case .green: (Color(hex: "#4BFF88"), Color(hex: "#040A06"))
        case .amber: (Color(hex: "#FFB43A"), Color(hex: "#0B0702"))
        case .white: (Color(hex: "#E6EEFF"), Color(hex: "#05070B"))
        case .cyan: (Color(hex: "#3BE8FF"), Color(hex: "#02090C"))
        }
    }
}

enum PaperTone: String, CaseIterable, Identifiable {
    case cream, ivory, night
    var id: String { rawValue }
    var title: String {
        switch self {
        case .cream: "Crème"
        case .ivory: "Ivoire"
        case .night: "Nuit"
        }
    }
}

enum BrutalColor: String, CaseIterable, Identifiable {
    case pink, yellow, blue, green
    var id: String { rawValue }
    var title: String {
        switch self {
        case .pink: "Rose"
        case .yellow: "Jaune"
        case .blue: "Bleu"
        case .green: "Vert"
        }
    }
    var color: Color {
        switch self {
        case .pink: Color(hex: "#FF8AD8")
        case .yellow: Color(hex: "#FFD84D")
        case .blue: Color(hex: "#7CB8FF")
        case .green: Color(hex: "#7BE495")
        }
    }
}

enum PanelPosition: String, CaseIterable, Identifiable {
    case upper, center
    var id: String { rawValue }
    var title: String { self == .upper ? "Tiers supérieur" : "Centre de l'écran" }
}

/// Tous les réglages, persistés dans UserDefaults. Les vues SwiftUI les observent directement.
final class AppSettings: ObservableObject {
    static let shared = AppSettings()
    private static let d = UserDefaults.standard

    private static func value<T>(_ key: String, _ fallback: T) -> T {
        d.object(forKey: key) as? T ?? fallback
    }

    // Général
    @Published var hotkeyID = value("hotkey", "cmd-space") { didSet { Self.d.set(hotkeyID, forKey: "hotkey") } }
    @Published var statsRevision = 0
    @Published var onboarded = value("onboarded", false) { didSet { Self.d.set(onboarded, forKey: "onboarded") } }
    @Published var showMenuBarIcon = value("showMenuBarIcon", true) {
        didSet {
            Self.d.set(showMenuBarIcon, forKey: "showMenuBarIcon")
            Controller.shared.updateStatusItem()
        }
    }

    // Apparence
    @Published var panelSize = PanelSize(rawValue: value("panelSize", "standard")) ?? .standard {
        didSet { Self.d.set(panelSize.rawValue, forKey: "panelSize") }
    }
    @Published var panelPosition = PanelPosition(rawValue: value("panelPosition", "upper")) ?? .upper {
        didSet { Self.d.set(panelPosition.rawValue, forKey: "panelPosition") }
    }
    @Published var panelStyle = PanelStyle(rawValue: value("panelStyle", "glass")) ?? .glass {
        didSet { Self.d.set(panelStyle.rawValue, forKey: "panelStyle") }
    }
    // Mouvement
    @Published var motionIntensity = MotionIntensity(rawValue: value("motionIntensity", "normal")) ?? .normal {
        didSet { Self.d.set(motionIntensity.rawValue, forKey: "motionIntensity") }
    }
    /// Multiplie la vitesse de toutes les animations (0,5× : deux fois plus lent).
    @Published var animationSpeed = value("animationSpeed", 1.0) { didSet { Self.d.set(animationSpeed, forKey: "animationSpeed") } }
    @Published var cascadeRows = value("cascadeRows", true) { didSet { Self.d.set(cascadeRows, forKey: "cascadeRows") } }
    @Published var launchEffects = value("launchEffects", true) { didSet { Self.d.set(launchEffects, forKey: "launchEffects") } }

    // Mise en page
    @Published var rowDensity = RowDensity(rawValue: value("rowDensity", "standard")) ?? .standard {
        didSet { Self.d.set(rowDensity.rawValue, forKey: "rowDensity") }
    }
    @Published var textScale = value("textScale", 1.0) { didSet { Self.d.set(textScale, forKey: "textScale") } }
    @Published var showAccessories = value("showAccessories", true) {
        didSet { Self.d.set(showAccessories, forKey: "showAccessories") }
    }
    @Published var showHints = value("showHints", true) { didSet { Self.d.set(showHints, forKey: "showHints") } }
    /// À l'ouverture, seulement la barre de recherche ; les résultats apparaissent quand on tape.
    @Published var focusMode = value("focusMode", false) { didSet { Self.d.set(focusMode, forKey: "focusMode") } }

    // Options des styles
    @Published var atelierShape = AtelierShape(rawValue: value("atelierShape", "cookie")) ?? .cookie {
        didSet { Self.d.set(atelierShape.rawValue, forKey: "atelierShape") }
    }
    @Published var atelierAppearance = ThemeAppearance(rawValue: value("atelierAppearance", "auto")) ?? .auto {
        didSet { Self.d.set(atelierAppearance.rawValue, forKey: "atelierAppearance") }
    }
    @Published var atelierColoredSelection = value("atelierColoredSelection", false) {
        didSet { Self.d.set(atelierColoredSelection, forKey: "atelierColoredSelection") }
    }
    @Published var phosphorColor = PhosphorColor(rawValue: value("phosphorColor", "green")) ?? .green {
        didSet { Self.d.set(phosphorColor.rawValue, forKey: "phosphorColor") }
    }
    @Published var paperTone = PaperTone(rawValue: value("paperTone", "cream")) ?? .cream {
        didSet { Self.d.set(paperTone.rawValue, forKey: "paperTone") }
    }
    @Published var brutalColor = BrutalColor(rawValue: value("brutalColor", "pink")) ?? .pink {
        didSet { Self.d.set(brutalColor.rawValue, forKey: "brutalColor") }
    }

    /// Tout ce qui change l'aspect du champ de recherche (police, couleurs) : il ne se reconfigure que si ça change.
    var styleSignature: String {
        [panelStyle.rawValue, atelierPalette.rawValue, "\(atelierSwap)", atelierAppearance.rawValue,
         phosphorColor.rawValue, paperTone.rawValue, brutalColor.rawValue, "\(textScale)", "\(StyleTokens.systemIsDark)"]
            .joined(separator: "|")
    }

    @Published var atelierPalette = AtelierPalette(rawValue: value("atelierPalette", "lime")) ?? .lime {
        didSet { Self.d.set(atelierPalette.rawValue, forKey: "atelierPalette") }
    }
    @Published var atelierSwap = value("atelierSwap", false) { didSet { Self.d.set(atelierSwap, forKey: "atelierSwap") } }
    // Verre : Liquid Glass pur par défaut (ni voile de flou par-dessus, ni teinte noire).
    @Published var glassMaterial = GlassMaterial(rawValue: value("glassMaterial", "liquid")) ?? .liquid {
        didSet { Self.d.set(glassMaterial.rawValue, forKey: "glassMaterial") }
    }
    @Published var glassTintHex = value("glassTintHex", "#000000") { didSet { Self.d.set(glassTintHex, forKey: "glassTintHex") } }
    /// 0 : aucune teinte.
    @Published var glassTintAmount = value("glassTintAmount", 0.0) {
        didSet { Self.d.set(glassTintAmount, forKey: "glassTintAmount") }
    }
    /// Verre dépoli seulement : opacité du givre (en dessous, le bureau apparaît net).
    @Published var frostOpacity = value("frostOpacity", 1.0) { didSet { Self.d.set(frostOpacity, forKey: "frostOpacity") } }
    @Published var glassBorder = value("glassBorder", false) { didSet { Self.d.set(glassBorder, forKey: "glassBorder") } }
    @Published var highlightHex = value("highlightHex", "#FFFFFF") { didSet { Self.d.set(highlightHex, forKey: "highlightHex") } }
    @Published var highlightAmount = value("highlightAmount", 0.12) {
        didSet { Self.d.set(highlightAmount, forKey: "highlightAmount") }
    }
    @Published var cornerRadius = value("cornerRadius", 26.0) { didSet { Self.d.set(cornerRadius, forKey: "cornerRadius") } }
    @Published var shadowStrength = value("shadowStrength", 1.0) { didSet { Self.d.set(shadowStrength, forKey: "shadowStrength") } }
    @Published var animations = value("animations", true) { didSet { Self.d.set(animations, forKey: "animations") } }
    @Published var haloSweep = value("haloSweep", true) { didSet { Self.d.set(haloSweep, forKey: "haloSweep") } }
    @Published var showSubtitles = value("showSubtitles", true) { didSet { Self.d.set(showSubtitles, forKey: "showSubtitles") } }

    // Recherche
    @Published var frecencyRanking = value("frecencyRanking", true) { didSet { Self.d.set(frecencyRanking, forKey: "frecencyRanking") } }
    @Published var learnQueries = value("learnQueries", true) { didSet { Self.d.set(learnQueries, forKey: "learnQueries") } }
    @Published var showRecents = value("showRecents", true) { didSet { Self.d.set(showRecents, forKey: "showRecents") } }
    @Published var shellCommands = value("shellCommands", true) { didSet { Self.d.set(shellCommands, forKey: "shellCommands") } }
    @Published var terminalID = value("terminalID", "") { didSet { Self.d.set(terminalID, forKey: "terminalID") } }
    @Published var editorID = value("editorID", "") { didSet { Self.d.set(editorID, forKey: "editorID") } }
    @Published var zshHistory = value("zshHistory", true) { didSet { Self.d.set(zshHistory, forKey: "zshHistory") } }
    @Published var useZoxide = value("useZoxide", true) { didSet { Self.d.set(useZoxide, forKey: "useZoxide") } }
    @Published var shellInteractive = value("shellInteractive", false) {
        didSet { Self.d.set(shellInteractive, forKey: "shellInteractive") }
    }
    // Agent (Hermes)
    @Published var agentEnabled = value("agentEnabled", true) { didSet { Self.d.set(agentEnabled, forKey: "agentEnabled") } }
    @Published var agentRouterModel = value("agentRouterModel", "gpt-6-luna") {
        didSet { Self.d.set(agentRouterModel, forKey: "agentRouterModel") }
    }
    @Published var agentRouterProvider = value("agentRouterProvider", "openai-codex") {
        didSet { Self.d.set(agentRouterProvider, forKey: "agentRouterProvider") }
    }
    @Published var agentDefaultProvider = value("agentDefaultProvider", "") {
        didSet { Self.d.set(agentDefaultProvider, forKey: "agentDefaultProvider") }
    }
    @Published var agentRouterReasoning = value("agentRouterReasoning", "low") {
        didSet { Self.d.set(agentRouterReasoning, forKey: "agentRouterReasoning") }
    }
    @Published var agentStrategy = value("agentStrategy", "auto") { didSet { Self.d.set(agentStrategy, forKey: "agentStrategy") } }
    @Published var agentDefaultModel = value("agentDefaultModel", "") {
        didSet { Self.d.set(agentDefaultModel, forKey: "agentDefaultModel") }
    }
    @Published var agentDefaultReasoning = value("agentDefaultReasoning", "") {
        didSet { Self.d.set(agentDefaultReasoning, forKey: "agentDefaultReasoning") }
    }
    @Published var agentWorkdir = value("agentWorkdir", "~") { didSet { Self.d.set(agentWorkdir, forKey: "agentWorkdir") } }
    /// Niveau rapide trop juste : "ask" (proposer), "research" ou "deep" (basculer automatiquement).
    @Published var agentEscalation = value("agentEscalation", "ask") {
        didSet { Self.d.set(agentEscalation, forKey: "agentEscalation") }
    }
    @Published var agentResearchProvider = value("agentResearchProvider", "anthropic") {
        didSet { Self.d.set(agentResearchProvider, forKey: "agentResearchProvider") }
    }
    @Published var agentResearchModel = value("agentResearchModel", "claude-sonnet-5-5") {
        didSet { Self.d.set(agentResearchModel, forKey: "agentResearchModel") }
    }
    @Published var agentResearchReasoning = value("agentResearchReasoning", "medium") {
        didSet { Self.d.set(agentResearchReasoning, forKey: "agentResearchReasoning") }
    }

    @Published var customCommands: [CustomCommand] = {
        guard let data = d.data(forKey: "customCommands"),
              let list = try? JSONDecoder().decode([CustomCommand].self, from: data) else { return CustomCommand.examples }
        return list
    }() {
        didSet { Self.d.set(try? JSONEncoder().encode(customCommands), forKey: "customCommands") }
    }

    // Presse-papiers & emoji
    @Published var clipboardEnabled = value("clipboardEnabled", true) {
        didSet {
            Self.d.set(clipboardEnabled, forKey: "clipboardEnabled")
            Controller.shared.clipboard.updateMonitoring()
        }
    }
    @Published var clipboardLimit = value("clipboardLimit", 300) { didSet { Self.d.set(clipboardLimit, forKey: "clipboardLimit") } }
    @Published var clipboardRetentionDays = value("clipboardRetentionDays", 0) {
        didSet { Self.d.set(clipboardRetentionDays, forKey: "clipboardRetentionDays") }
    }
    @Published var clipboardImages = value("clipboardImages", true) { didSet { Self.d.set(clipboardImages, forKey: "clipboardImages") } }
    @Published var clipboardIgnored = value("clipboardIgnored", ["com.apple.keychainaccess"]) {
        didSet { Self.d.set(clipboardIgnored, forKey: "clipboardIgnored") }
    }
    @Published var pasteOnEnter = value("pasteOnEnter", true) { didSet { Self.d.set(pasteOnEnter, forKey: "pasteOnEnter") } }

    /// Surlignage de la sélection (liste, grille, emoji).
    var highlight: Color { Color(hex: highlightHex).opacity(highlightAmount) }

    /// Apparence d'origine (style, couleurs, mise en page, panneau).
    func resetAppearance() {
        panelStyle = .glass
        apply(LookPreset.all[0])
        cornerRadius = 26
        shadowStrength = 1
        rowDensity = .standard
        textScale = 1
        showSubtitles = true
        showAccessories = true
        showHints = true
        focusMode = false
        atelierPalette = .lime
        atelierSwap = false
        atelierShape = .cookie
        atelierAppearance = .auto
        atelierColoredSelection = false
        phosphorColor = .green
        paperTone = .cream
        brutalColor = .pink
    }

    func apply(_ preset: LookPreset) {
        glassMaterial = preset.material
        glassTintHex = preset.tintHex
        glassTintAmount = preset.tintAmount
        frostOpacity = 1
        glassBorder = preset.border
        highlightHex = preset.highlightHex
        highlightAmount = preset.highlightAmount
    }

    func matches(_ preset: LookPreset) -> Bool {
        glassMaterial == preset.material && glassBorder == preset.border
            && abs(glassTintAmount - preset.tintAmount) < 0.005 && (preset.tintAmount == 0 || glassTintHex == preset.tintHex)
            && highlightHex == preset.highlightHex && abs(highlightAmount - preset.highlightAmount) < 0.005
    }
}

enum GlassMaterial: String, CaseIterable, Identifiable {
    case liquid, clear, frosted
    var id: String { rawValue }

    var title: String {
        switch self {
        case .liquid: "Liquid Glass"
        case .clear: "Verre clair"
        case .frosted: "Verre dépoli"
        }
    }

    var detail: String {
        switch self {
        case .liquid: "Le verre de macOS : réfraction et reflets sur les bords."
        case .clear: "Liquid Glass plus transparent : le bureau reste bien visible."
        case .frosted: "Flou classique, plus opaque, sans effet de lentille."
        }
    }

    /// Liquid Glass n'existe qu'à partir de macOS 26 : avant, tout est rendu en verre dépoli.
    static var liquidAvailable: Bool {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) { return true }
        #endif
        return false
    }
}

/// Thème tout prêt : matériau, teinte et surlignage.
struct LookPreset: Identifiable {
    let name: String
    let material: GlassMaterial
    var tintHex = "#000000"
    var tintAmount = 0.0
    var border = false
    var highlightHex = "#FFFFFF"
    var highlightAmount = 0.12
    var id: String { name }

    static let all: [LookPreset] = [
        LookPreset(name: "Liquid Glass", material: .liquid),
        LookPreset(name: "Cristal", material: .clear, highlightAmount: 0.18),
        LookPreset(name: "Fumé", material: .liquid, tintAmount: 0.45),
        LookPreset(name: "Givré", material: .frosted, tintAmount: 0.15, border: true),
        LookPreset(name: "Aurore", material: .liquid, tintHex: "#6A3DF0", tintAmount: 0.25,
                   highlightHex: "#D08CFF", highlightAmount: 0.3),
        LookPreset(name: "Océan", material: .liquid, tintHex: "#0A6CFF", tintAmount: 0.2,
                   highlightHex: "#5FD0FF", highlightAmount: 0.28),
        LookPreset(name: "Braise", material: .liquid, tintHex: "#FF5A1F", tintAmount: 0.18,
                   highlightHex: "#FFB066", highlightAmount: 0.3),
        LookPreset(name: "Forêt", material: .liquid, tintHex: "#11A36A", tintAmount: 0.2,
                   highlightHex: "#7CF0B5", highlightAmount: 0.26),
    ]
}

extension Color {
    /// « #RRGGBB » (sRGB) ; blanc si illisible.
    init(hex: String) {
        let digits = hex.trimmingCharacters(in: CharacterSet(charactersIn: "# "))
        let v = UInt32(digits, radix: 16) ?? 0xFFFFFF
        self.init(.sRGB, red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
                  blue: Double(v & 0xFF) / 255)
    }

    var hexString: String {
        guard let c = NSColor(self).usingColorSpace(.sRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X", Int((c.redComponent * 255).rounded()),
                      Int((c.greenComponent * 255).rounded()), Int((c.blueComponent * 255).rounded()))
    }
}

/// Apps externes détectées pour « ouvrir dans le terminal / l'éditeur ».
enum ExternalApps {
    static let terminals: [(id: String, name: String)] = [
        ("com.mitchellh.ghostty", "Ghostty"), ("com.googlecode.iterm2", "iTerm"), ("dev.warp.Warp-Stable", "Warp"),
        ("net.kovidgoyal.kitty", "kitty"), ("io.alacritty", "Alacritty"), ("com.apple.Terminal", "Terminal"),
    ]
    static let editors: [(id: String, name: String)] = [
        ("com.todesktop.230313mzl4w4u92", "Cursor"), ("com.microsoft.VSCode", "Visual Studio Code"),
        ("dev.zed.Zed", "Zed"), ("com.sublimetext.4", "Sublime Text"), ("com.panic.Nova", "Nova"),
        ("com.apple.dt.Xcode", "Xcode"), ("com.jetbrains.intellij", "IntelliJ IDEA"),
    ]

    static func installed(_ list: [(id: String, name: String)]) -> [(id: String, name: String)] {
        list.filter { NSWorkspace.shared.urlForApplication(withBundleIdentifier: $0.id) != nil }
    }
}
