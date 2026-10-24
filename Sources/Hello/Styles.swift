import AppKit
import SwiftUI

/// Direction artistique du panneau. « Verre » suit les réglages de verre (matériau, teinte, surlignage) ;
/// les autres sont des styles complets : fond, typographie, sélection, touches, icônes et mouvement.
enum PanelStyle: String, CaseIterable, Identifiable {
    case glass, atelier, glyph, phosphor, paper, brutal
    var id: String { rawValue }

    var title: String {
        switch self {
        case .glass: "Verre"
        case .atelier: "Atelier Expressif"
        case .glyph: "Atelier Glyphe"
        case .phosphor: "Phosphore"
        case .paper: "Papier"
        case .brutal: "Néo-brutal"
        }
    }

    var detail: String {
        switch self {
        case .glass: "Liquid Glass ou verre dépoli, réglable ci-dessous."
        case .atelier: "Material 3 Expressive : barre de recherche en pilule, listes segmentées, formes qui se transforment, "
            + "Google Sans Flex et ressorts. Cadre noir, cartes blanches et deux couleurs signal au choix."
        case .glyph: "Un noir chaud et une seule couleur : panneau en retrait dans un cadre noir, sélection inversée, "
            + "libellés en chasse fixe, logo en points et ressorts. La Nuit passe tout dans un seul rouge."
        case .phosphor: "Écran cathodique : vert phosphore, tout en chasse fixe, sélection en vidéo inverse."
        case .paper: "Papier crème, titres à empattements, filets fins et marque-page vermillon."
        case .brutal: "Crème, gros contours noirs, ombres pleines et couleurs franches qui rebondissent."
        }
    }

    var symbol: String {
        switch self {
        case .glass: "drop.fill"
        case .atelier: "square.grid.2x2.fill"
        case .glyph: "circle.grid.3x3.fill"
        case .phosphor: "terminal.fill"
        case .paper: "book.closed.fill"
        case .brutal: "square.stack.3d.down.forward.fill"
        }
    }

    var tokens: StyleTokens { StyleTokens.make(self) }

    /// Signature de mouvement du style (voir Motion.swift).
    var reveal: RevealStyle {
        switch self {
        case .glass: .glass
        case .atelier: .unfold
        case .glyph: .wave
        case .phosphor: .crt
        case .paper: .page
        case .brutal: .slam
        }
    }
}

/// Thèmes de couleurs d'Atelier : deux couleurs signal sur une base neutre (noir, gris, blanc), comme les paires
/// d'accents de l'artifact. « macOS » suit la couleur d'accentuation du système (la couleur dynamique de Material).
enum AtelierPalette: String, CaseIterable, Identifiable {
    case lime, orange, pink, yellow, red, system
    var id: String { rawValue }

    var title: String {
        switch self {
        case .lime: "Lime / Lavande"
        case .orange: "Orange / Ciel"
        case .pink: "Rose / Menthe"
        case .yellow: "Jaune / Outremer"
        case .red: "Rouge / Sable"
        case .system: "Accent macOS"
        }
    }

    /// Accent principal (sélection, bouton, touche ↵) et accent secondaire (pastilles d'icônes).
    var colors: (primary: Color, secondary: Color) {
        switch self {
        case .lime: (Color(hex: "#D4F54A"), Color(hex: "#B7AEF7"))
        case .orange: (Color(hex: "#FF6A2B"), Color(hex: "#8FD3FF"))
        case .pink: (Color(hex: "#FF5FA2"), Color(hex: "#7FF0C4"))
        case .yellow: (Color(hex: "#FFD23F"), Color(hex: "#7D95FF"))
        case .red: (Color(hex: "#FF4F3A"), Color(hex: "#EFE2C4"))
        case .system: Self.systemColors
        }
    }

    /// Accent du système éclairci (texte noir lisible dessus) et sa version pastel.
    private static var systemColors: (primary: Color, secondary: Color) {
        let accent = NSColor.controlAccentColor.usingColorSpace(.sRGB) ?? .systemBlue
        return (Color(nsColor: accent.blended(withFraction: 0.25, of: .white) ?? accent),
                Color(nsColor: accent.blended(withFraction: 0.6, of: .white) ?? accent))
    }

    /// Paire effectivement utilisée (inversée si demandé dans les réglages).
    static var current: (primary: Color, secondary: Color) {
        let colors = AppSettings.shared.atelierPalette.colors
        return AppSettings.shared.atelierSwap ? (colors.secondary, colors.primary) : colors
    }
}

/// Accent unique d'Atelier Glyphe (les six de l'artifact). Il ne décore jamais : il marque l'action principale
/// (touche ↵), le logo et l'élément choisi. « Mono » reprend la couleur du texte.
enum GlyphAccent: String, CaseIterable, Identifiable {
    case orange, amber, green, coral, violet, mono
    var id: String { rawValue }

    var title: String {
        switch self {
        case .orange: "Orange"
        case .amber: "Ambre"
        case .green: "Vert"
        case .coral: "Corail"
        case .violet: "Violet"
        case .mono: "Mono"
        }
    }

    /// Accent et texte posé dessus ; nil pour Mono (il dépend de l'apparence).
    var colors: (accent: Color, on: Color)? {
        switch self {
        case .orange: (Color(hex: "#ED6A0C"), .white)
        case .amber: (Color(hex: "#EFB85C"), Color(hex: "#111111"))
        case .green: (Color(hex: "#78DD8B"), Color(hex: "#111111"))
        case .coral: (Color(hex: "#FF6C67"), Color(hex: "#111111"))
        case .violet: (Color(hex: "#A25BFF"), .white)
        case .mono: nil
        }
    }

    /// Couleur de la pastille dans les réglages.
    var swatch: Color { colors?.accent ?? Color(hex: "#F1F1F1") }
}

/// Tout ce qu'un style décide. Les vues du panneau lisent `StyleTokens.current` une fois par rendu.
struct StyleTokens {
    enum Surface {
        case glass
        case solid(Color)
        /// Cadre plein, contenu posé sur un panneau intérieur arrondi (Atelier).
        case inset(frame: Color, pane: Color)
    }

    enum HeaderStyle { case plain, kicker, comment, serifItalic, emphasized, label }
    enum TileStyle {
        case tinted, cookie, outline, bordered
        /// Carré aux coins doux qui s'arrondissent et prennent l'accent une fois choisi (Glyphe).
        case glyph(rest: Color, ink: Color, selected: Color, selectedInk: Color)
    }
    enum SearchMark { case logo, symbol(String), prompt(String) }

    var surface: Surface
    /// Contenu sombre (texte clair) : apparence de la fenêtre, champ de recherche, menus contextuels.
    var dark: Bool
    var ink: Color
    /// Texte de l'en-tête et du pied de page (différent de `ink` quand ils sont posés sur un cadre).
    var chromeInk: Color
    var chromeDark: Bool
    var accent: Color
    /// Second accent (pastilles d'icônes d'Atelier).
    var accent2: Color = .accentColor
    var live: Color
    var toast: Color

    var selectionFill: Color
    var selectionInk: Color?
    var selectionBorder: Color?
    var selectionBar: Color?
    var selectionHardShadow: CGFloat?
    var rowRadius: CGFloat
    var cellRadius: CGFloat

    /// nil : arrondi réglé par l'utilisateur.
    var radius: CGFloat?
    var border: (color: Color, width: CGFloat)?
    /// Ombre pleine décalée (Néo-brutal) à la place de l'ombre floue.
    var hardShadow: CGFloat?
    var divider: Color

    var design: Font.Design = .default
    var titleDesign: Font.Design?
    var searchWidth: Font.Width?
    var titleWeight: Font.Weight = .medium
    var searchWeight: NSFont.Weight = .regular
    var header: HeaderStyle = .plain
    /// Devant le champ de recherche : le logo, dans la matière du style.
    var mark: SearchMark = .logo
    var markSkin: HelloMark.Skin = .glass
    /// Police variable (axes wght / wdth / opsz) ; nil ou absente du Mac : police système.
    var fontFamily: String?
    /// Police d'affiche du champ de recherche (titres larges) ; nil ou absente : `fontFamily`, puis le système.
    var displayFamily: String?
    /// Filet d'un pixel autour du panneau intérieur (`.inset`).
    var paneBorder: Color?

    /// Barre de recherche en pilule posée dans l'en-tête (Material) : elle prend les couleurs du contenu.
    var searchBar: Color?
    /// Bouton icône plein (bouton Applications de l'en-tête).
    var iconButton: (fill: Color, ink: Color)?
    /// Liste segmentée : chaque ligne est une carte, coins larges aux bords du groupe, serrés entre les lignes.
    var segmented: (card: Color, outer: CGFloat, inner: CGFloat)?
    /// Métadonnées (accessoires) plus lisibles, pour les styles à fort contraste.
    var strongMeta = false

    var keyFill: Color
    var keyInk: Color
    var keyBorder: Color?
    var primaryKeyFill: Color?
    var primaryKeyInk: Color?
    var keyHardShadow = false
    /// Touches en chasse fixe, comme les libellés (`kbd` de Glyphe).
    var monoKeys = false

    var tile: TileStyle = .tinted
    /// Icônes d'apps monochromes (Phosphore).
    var iconTint: Color?
    var scanlines = false
    /// Mouvement de la sélection ; nil : saut net.
    var motion: Animation?
    /// Sélection remplie d'une couleur vive (Atelier) : la pastille sélectionnée passe alors en encre.
    var coloredSelection = false
    /// Curseur bloc qui clignote devant la ligne sélectionnée (Phosphore).
    var blinkingCursor = false

    static var current: StyleTokens { AppSettings.shared.panelStyle.tokens }

    /// En-tête : sur le cadre (chrome), ou dans la barre de recherche (couleurs du contenu).
    var headerInk: Color { searchBar != nil ? ink : chromeInk }
    var headerDark: Bool { searchBar != nil ? dark : chromeDark }

    /// Couleurs du champ de recherche (AppKit). Le verre garde les couleurs système.
    var searchNSColor: NSColor {
        if case .glass = surface { return .labelColor }
        return NSColor(headerInk)
    }

    var placeholderNSColor: NSColor {
        if case .glass = surface { return .placeholderTextColor }
        return NSColor(headerInk).withAlphaComponent(0.45)
    }

    // MARK: - Typographie

    func font(_ size: CGFloat, _ weight: Font.Weight = .regular, title: Bool = false, width: CGFloat = 100) -> Font {
        if let fontFamily, let font = VariableFont.make(fontFamily, size: size, weight: VariableFont.value(weight), width: width) {
            return Font(font as CTFont)
        }
        return .system(size: size, weight: weight, design: title ? (titleDesign ?? design) : design)
    }

    /// Taille de texte réglée par l'utilisateur (lignes de résultats et recherche).
    var textScale: CGFloat { CGFloat(AppSettings.shared.textScale) }

    var titleFont: Font { font(13.5 * textScale, titleWeight, title: true) }

    var searchFont: NSFont { displayNSFont((21 * textScale).rounded()) }

    /// Police du champ de recherche, à n'importe quelle taille (les aperçus des réglages la reprennent en petit).
    func displayNSFont(_ size: CGFloat) -> NSFont {
        for family in [displayFamily, fontFamily].compactMap({ $0 }) {
            if let font = VariableFont.make(family, size: size, weight: 500) { return font }
        }
        var font = NSFont.systemFont(ofSize: size, weight: searchWeight, width: searchWidth.map(Self.nsWidth) ?? .standard)
        let nsDesign: NSFontDescriptor.SystemDesign? = switch titleDesign ?? design {
        case .serif: .serif
        case .monospaced: .monospaced
        case .rounded: .rounded
        default: nil
        }
        if let nsDesign, let descriptor = font.fontDescriptor.withDesign(nsDesign) {
            font = NSFont(descriptor: descriptor, size: size) ?? font
        }
        return font
    }

    private static func nsWidth(_ width: Font.Width) -> NSFont.Width {
        switch width {
        case .expanded: .expanded
        case .condensed: .condensed
        case .compressed: .compressed
        default: .standard
        }
    }

    func sectionTitle(_ text: String) -> String {
        switch header {
        case .plain, .serifItalic, .emphasized: text
        case .kicker, .label: text.uppercased()
        case .comment: "// " + text.lowercased()
        }
    }

    var sectionFont: Font {
        switch header {
        case .plain: font(11, .semibold)
        case .kicker: .system(size: 10, weight: .heavy).width(.expanded)
        case .comment: .system(size: 11, weight: .regular, design: .monospaced)
        case .serifItalic: .system(size: 12.5, weight: .regular, design: .serif).italic()
        case .emphasized: font(12.5, .bold, width: 112)
        case .label: .system(size: 10.5, weight: .medium, design: .monospaced)
        }
    }

    var sectionTracking: CGFloat {
        switch header {
        case .kicker: 1.2
        case .label: 0.7
        default: 0
        }
    }

    // MARK: - Fabrique

    static func make(_ style: PanelStyle) -> StyleTokens {
        switch style {
        case .glass: glass
        case .atelier: atelier(dark: atelierIsDark)
        case .glyph: glyph(AppSettings.shared.glyphAccent, appearance: AppSettings.shared.glyphAppearance)
        case .phosphor: phosphor(AppSettings.shared.phosphorColor)
        case .paper: paper(AppSettings.shared.paperTone)
        case .brutal: brutal(AppSettings.shared.brutalColor)
        }
    }

    static var systemIsDark: Bool {
        NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
    }

    private static var atelierIsDark: Bool {
        switch AppSettings.shared.atelierAppearance {
        case .auto: systemIsDark
        case .light: false
        case .dark: true
        }
    }

    private static var glass: StyleTokens {
        StyleTokens(
            surface: .glass, dark: true, ink: .primary, chromeInk: .primary, chromeDark: true,
            accent: .accentColor, live: .green, toast: .green,
            selectionFill: AppSettings.shared.highlight, rowRadius: 11, cellRadius: 18,
            divider: Color.white.opacity(0.08), markSkin: .ink(.primary),
            keyFill: Color.white.opacity(0.08), keyInk: Color.white.opacity(0.55),
            motion: .snappy(duration: 0.18))
    }

    /// Base neutre de l'artifact « Atelier Expressif » (Material 3 Expressive), contraste renforcé.
    /// Les deux couleurs signal viennent du thème (`AtelierPalette`).
    enum Atelier {
        static let frame = Color(hex: "#111112")
        static let onFrame = Color(hex: "#F4F4F0")
        static let onFrameSoft = Color(hex: "#A3A3A9")
        static let pane = Color(hex: "#E3E3DC")
        static let card = Color(hex: "#FFFFFF")
        static let ink = Color(hex: "#111112")
        static let keyFill = Color(hex: "#2C2C2F")
        static let red = Color(hex: "#FF4F3A")
        // Nuit
        static let frameNight = Color(hex: "#000000")
        static let paneNight = Color(hex: "#1C1C1F")
        static let cardNight = Color(hex: "#2C2C31")
        /// Ressort « spatial » de Material 3 Expressive (amortissement 0,8 : un léger dépassement).
        static let spring = Animation.spring(response: 0.32, dampingFraction: 0.8)
    }

    private static func atelier(dark: Bool) -> StyleTokens {
        let a = Atelier.self
        let (primary, secondary) = AtelierPalette.current
        let ink = dark ? a.onFrame : a.ink
        let card = dark ? a.cardNight : a.card
        // Sélection pleine à fort contraste : noire sur fond clair, accent sur fond sombre (ou en couleur, au choix).
        let colored = dark || AppSettings.shared.atelierColoredSelection
        return StyleTokens(
            surface: .inset(frame: dark ? a.frameNight : a.frame, pane: dark ? a.paneNight : a.pane),
            dark: dark, ink: ink, chromeInk: a.onFrame, chromeDark: true,
            accent: primary, accent2: secondary, live: a.red, toast: primary,
            selectionFill: colored ? primary : a.ink, selectionInk: colored ? a.ink : a.onFrame,
            rowRadius: 22, cellRadius: 28, radius: 30, divider: .clear,
            titleWeight: .semibold, header: .emphasized, markSkin: .atelier(ring: ink, dot: secondary),
            fontFamily: "Google Sans Flex",
            searchBar: card, iconButton: (primary, a.ink), segmented: (card, 20, 5), strongMeta: true,
            keyFill: a.keyFill, keyInk: a.onFrame.opacity(0.85),
            primaryKeyFill: primary, primaryKeyInk: a.ink,
            tile: .cookie,
            motion: a.spring, coloredSelection: colored)
    }

    /// Valeurs de l'artifact « Atelier Glyphe » : cadre noir chaud (identique dans tous les thèmes), panneau en
    /// retrait clair ou sombre, gris superposés, et la Nuit où tout passe dans un seul rouge.
    enum Glyph {
        static let frame = Color(hex: "#050403")
        static let onFrame = Color.white
        static let frameHi = Color.white.opacity(0.07)
        static let frameLine = Color.white.opacity(0.1)
        // Sombre
        static let pane = Color(hex: "#080604")
        static let ctrl = Color(hex: "#242424")
        static let inv = Color(hex: "#F1F1F1")
        static let onInv = Color(hex: "#111111")
        // Clair
        static let paneLight = Color(hex: "#EFEEEC")
        static let ctrlLight = Color(hex: "#E7E5E2")
        static let invLight = Color(hex: "#080604")
        // Nuit : rouge à 85 % (le réglage de luminosité de l'artifact), filets rouges plus ou moins denses.
        static let red = Color(hex: "#D94433")
        static func redLine(_ opacity: Double) -> Color { Color(red: 1, green: 60 / 255, blue: 40 / 255).opacity(opacity) }
        /// Ressort « défaut » de l'artifact : ça arrive, ça se pose, avec un léger dépassement.
        static let spring = Animation.spring(response: 0.36, dampingFraction: 0.78)
    }

    private static func glyph(_ choice: GlyphAccent, appearance: GlyphAppearance) -> StyleTokens {
        let g = Glyph.self
        let night = appearance == .night
        let dark = switch appearance {
        case .auto: systemIsDark
        case .light: false
        case .dark, .night: true
        }
        let ink = night ? g.red : dark ? g.onFrame : g.onInv
        // Sélection inversée, comme l'élément coché d'un menu : clair sur sombre, noir sur clair, rouge la nuit.
        let selection = night ? g.red : dark ? g.inv : g.invLight
        let selectionInk = night ? Color.black : dark ? g.onInv : .white
        let (accent, onAccent) = night ? (g.red, .black) : choice.colors ?? (ink, dark ? g.onInv : .white)
        // Mono (et la Nuit) : l'accent se confond avec la sélection, la pastille choisie s'inverse plutôt.
        let blends = night || choice == .mono
        // Logo et touche ↵ sont posés sur le cadre noir : Mono y passe en blanc.
        let frameAccent = !night && choice == .mono ? g.onFrame : accent
        let frameOnAccent = !night && choice == .mono ? g.frame : onAccent
        let chrome = night ? g.red : g.onFrame
        return StyleTokens(
            surface: .inset(frame: night ? .black : g.frame, pane: night ? .black : dark ? g.pane : g.paneLight),
            dark: dark, ink: ink, chromeInk: chrome, chromeDark: true,
            accent: accent, accent2: accent, live: accent, toast: chrome,
            selectionFill: selection, selectionInk: selectionInk,
            rowRadius: 12, cellRadius: 14, radius: 22, divider: .clear,
            searchWidth: .expanded, titleWeight: .semibold, searchWeight: .medium, header: .label,
            markSkin: .glyph(ring: chrome, dot: frameAccent),
            fontFamily: "Red Hat Display", displayFamily: "Zalando Sans Expanded",
            paneBorder: night ? g.redLine(0.58) : dark ? g.frameLine : nil,
            keyFill: night ? .clear : g.frameHi, keyInk: night ? g.red : g.onFrame.opacity(0.62),
            keyBorder: night ? g.redLine(0.58) : Color.white.opacity(0.14),
            primaryKeyFill: frameAccent, primaryKeyInk: frameOnAccent, monoKeys: true,
            tile: .glyph(rest: night ? g.redLine(0.1) : dark ? g.ctrl : g.ctrlLight, ink: ink,
                         selected: blends ? selectionInk : accent, selectedInk: blends ? selection : onAccent),
            motion: g.spring)
    }

    private static func phosphor(_ color: PhosphorColor) -> StyleTokens {
        let (green, screen) = color.colors
        return StyleTokens(
            surface: .solid(screen), dark: true, ink: green, chromeInk: green, chromeDark: true,
            accent: green, live: green, toast: green,
            selectionFill: green, selectionInk: screen, rowRadius: 3, cellRadius: 6,
            radius: 10, border: (green.opacity(0.35), 1), divider: green.opacity(0.22),
            design: .monospaced, titleWeight: .regular, header: .comment, markSkin: .phosphor(green),
            keyFill: .clear, keyInk: green.opacity(0.75), keyBorder: green.opacity(0.4),
            primaryKeyFill: green, primaryKeyInk: screen,
            tile: .outline, iconTint: green, scanlines: true, motion: nil, blinkingCursor: true)
    }

    private static func paper(_ tone: PaperTone) -> StyleTokens {
        let night = tone == .night
        let ink = Color(hex: night ? "#EDE6D8" : "#211C17")
        let vermilion = Color(hex: night ? "#FF7A45" : "#D9480F")
        let sheet = Color(hex: tone == .cream ? "#F4EFE6" : tone == .ivory ? "#FBFAF5" : "#1E1B17")
        let selection = Color(hex: tone == .cream ? "#E8DFCE" : tone == .ivory ? "#EFECE2" : "#2E2923")
        return StyleTokens(
            surface: .solid(sheet), dark: night, ink: ink, chromeInk: ink, chromeDark: night,
            accent: vermilion, live: vermilion, toast: vermilion,
            selectionFill: selection, selectionBar: vermilion, rowRadius: 6, cellRadius: 14,
            radius: 18, border: (ink.opacity(0.14), 1), divider: ink.opacity(0.14),
            titleDesign: .serif, titleWeight: .semibold, header: .serifItalic, markSkin: .paper(ink: ink, dot: vermilion),
            keyFill: .clear, keyInk: ink.opacity(0.6), keyBorder: ink.opacity(0.25),
            primaryKeyFill: vermilion, primaryKeyInk: .white,
            motion: .easeInOut(duration: 0.2))
    }

    private static func brutal(_ color: BrutalColor) -> StyleTokens {
        let black = Color.black
        return StyleTokens(
            surface: .solid(Color(hex: "#FFF4D6")), dark: false, ink: black, chromeInk: black, chromeDark: false,
            accent: Color(hex: "#3D6BFF"), live: Color(hex: "#00B86B"), toast: Color(hex: "#3D6BFF"),
            selectionFill: color.color, selectionBorder: black, selectionHardShadow: 3,
            rowRadius: 10, cellRadius: 16, radius: 16, border: (black, 3), hardShadow: 8, divider: black,
            titleWeight: .bold, searchWeight: .heavy, header: .kicker, markSkin: .brutal(color.color),
            keyFill: .white, keyInk: black, keyBorder: black,
            primaryKeyFill: color == .yellow ? BrutalColor.pink.color : BrutalColor.yellow.color, primaryKeyInk: black,
            keyHardShadow: true,
            tile: .bordered, motion: .spring(response: 0.24, dampingFraction: 0.55))
    }
}

// MARK: - Environnement

private struct StyleTokensKey: EnvironmentKey {
    static let defaultValue = PanelStyle.glass.tokens
}

private struct RowSelectedKey: EnvironmentKey {
    static let defaultValue = false
}

/// Flou du verre (0 : clair, seul le fumé reste ; 1 : rendu normal) et animation pour y aller.
struct GlassFrost: Equatable {
    var value = 1.0
    var animation: Animation? = nil
    static func == (a: GlassFrost, b: GlassFrost) -> Bool { a.value == b.value }
}

private struct GlassFrostKey: EnvironmentKey {
    static let defaultValue = GlassFrost()
}

extension EnvironmentValues {
    /// L'élément qui contient la vue est sélectionné (pastilles d'icônes qui changent de forme).
    var rowSelected: Bool {
        get { self[RowSelectedKey.self] }
        set { self[RowSelectedKey.self] = newValue }
    }

    /// Flou du verre, animé à l'ouverture du Verre.
    var glassFrost: GlassFrost {
        get { self[GlassFrostKey.self] }
        set { self[GlassFrostKey.self] = newValue }
    }

    /// Style des composants partagés (touches, sélection, icônes) : celui du panneau, ou celui d'une vignette.
    var styleTokens: StyleTokens {
        get { self[StyleTokensKey.self] }
        set { self[StyleTokensKey.self] = newValue }
    }
}

// MARK: - Fond du panneau

extension View {
    /// Fond du panneau selon le style (le verre garde son rendu Liquid Glass / dépoli).
    @ViewBuilder
    func styledSurface(_ style: StyleTokens, cornerRadius radius: CGFloat) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        switch style.surface {
        case .glass:
            glassPanel(cornerRadius: radius)
        case .solid(let color), .inset(let color, _):
            background(shape.fill(color))
                .overlay {
                    if style.scanlines { Scanlines().clipShape(shape) }
                }
                .overlay {
                    if let border = style.border {
                        shape.strokeBorder(border.color, lineWidth: border.width).allowsHitTesting(false)
                    }
                }
        }
    }

    /// Atelier : la zone de résultats est un panneau intérieur arrondi, posé dans le cadre.
    @ViewBuilder
    func styledPane(_ style: StyleTokens, panelRadius: CGFloat) -> some View {
        if case .inset(_, let pane) = style.surface {
            let shape = RoundedRectangle(cornerRadius: max(panelRadius - 8, 8), style: .continuous)
            background(shape.fill(pane)).clipShape(shape)
                .overlay {
                    if let border = style.paneBorder {
                        shape.strokeBorder(border, lineWidth: 1).allowsHitTesting(false)
                    }
                }
                .padding(.horizontal, 8)
        } else {
            self
        }
    }
}

/// Lignes de balayage d'un écran cathodique : un motif d'1 × 3 px répété (aucun calcul par image).
struct Scanlines: View {
    private static let pattern: NSImage = {
        let image = NSImage(size: NSSize(width: 1, height: 3))
        image.lockFocus()
        NSColor.black.withAlphaComponent(0.28).setFill()
        NSRect(x: 0, y: 0, width: 1, height: 1).fill()
        image.unlockFocus()
        return image
    }()

    var body: some View {
        Rectangle()
            .fill(ImagePaint(image: Image(nsImage: Self.pattern)))
            .allowsHitTesting(false)
    }
}

/// Polices variables installées sur le Mac (Google Sans Flex…), réglées axe par axe et gardées en cache.
enum VariableFont {
    private static var cache: [String: NSFont] = [:]
    private static var missing = Set<String>()

    static func make(_ family: String, size: CGFloat, weight: CGFloat, width: CGFloat = 100) -> NSFont? {
        let key = "\(family)|\(size)|\(weight)|\(width)"
        if let font = cache[key] { return font }
        guard !missing.contains(family),
              let base = NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: size) else {
            missing.insert(family)
            return nil
        }
        let axes: [NSNumber: CGFloat] = [tag("wght"): weight, tag("wdth"): width, tag("opsz"): min(max(size, 6), 144)]
        let font = NSFont(descriptor: base.fontDescriptor.addingAttributes([.variation: axes]), size: size) ?? base
        cache[key] = font
        return font
    }

    static func value(_ weight: Font.Weight) -> CGFloat {
        switch weight {
        case .ultraLight: 200
        case .thin: 250
        case .light: 300
        case .medium: 500
        case .semibold: 600
        case .bold: 700
        case .heavy: 800
        case .black: 900
        default: 400
        }
    }

    private static func tag(_ name: String) -> NSNumber {
        NSNumber(value: name.utf8.reduce(UInt32(0)) { $0 << 8 | UInt32($1) })
    }
}

/// Forme « cookie » de Material 3 Expressive : un cercle festonné. `depth` à 0 : cercle (animable, pour le morphing).
struct CookieShape: Shape {
    var lobes: Int = 9
    var depth: CGFloat

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let steps = 144
        var path = Path()
        for step in 0...steps {
            let angle = 2 * .pi * CGFloat(step) / CGFloat(steps) - .pi / 2
            let r = radius * (1 - depth * (1 - cos(CGFloat(lobes) * angle)) / 2)
            let point = CGPoint(x: center.x + r * cos(angle), y: center.y + r * sin(angle))
            step == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
    }
}

/// Pastille d'icône d'un symbole, selon le style.
struct SymbolTile: View {
    let name: String
    let tint: Color
    @Environment(\.styleTokens) private var style
    @Environment(\.rowSelected) private var selected

    var body: some View {
        let glyph = Image(systemName: name).font(.system(size: 13, weight: .semibold))
        switch style.tile {
        case .tinted:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint.gradient)
                .overlay(glyph.foregroundStyle(.white))
                .padding(1)
        case .cookie:
            // Cercle lavande ; sélectionné, il se festonne en cookie et tourne (morphing M3 Expressive),
            // dans la couleur qui tranche le plus sur la carte sélectionnée.
            let a = StyleTokens.Atelier.self
            // Sur une sélection colorée, la pastille passe en encre (et inversement).
            let colored = style.coloredSelection
            let fill = selected ? (colored ? a.ink : style.accent) : style.accent2
            let ink = selected && colored ? style.accent : a.ink
            let shape = AppSettings.shared.atelierShape
            CookieShape(lobes: shape.lobes, depth: selected ? shape.depth : 0)
                .fill(fill)
                .scaleEffect(selected && shape == .circle ? 1.12 : 1)
                .rotationEffect(.degrees(selected ? 360 / Double(max(shape.lobes, 2)) / 2 + 20 : 0))
                .overlay(glyph.foregroundStyle(ink))
        case .outline:
            RoundedRectangle(cornerRadius: 3)
                .strokeBorder(.secondary, lineWidth: 1)
                .overlay(glyph.font(.system(size: 12, weight: .regular)))
                .padding(2)
        case .bordered:
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(tint)
                .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous).strokeBorder(.black, lineWidth: 1.5))
                .overlay(glyph.foregroundStyle(.black))
                .padding(1)
        case .glyph(let rest, let ink, let on, let onInk):
            // « Des coins qui réagissent » : choisie, la pastille s'arrondit et prend l'accent, sur un ressort.
            RoundedRectangle(cornerRadius: selected ? 9 : 6, style: .continuous)
                .fill(selected ? on : rest)
                .overlay(glyph.foregroundStyle(selected ? onInk : ink).symbolVariant(selected ? .fill : .none))
                .padding(1)
                .animation(StyleTokens.Glyph.spring, value: selected)
        }
    }
}

extension View {
    /// Icônes d'apps monochromes pour les styles qui le demandent.
    @ViewBuilder
    func styledIcon(_ style: StyleTokens) -> some View {
        if let tint = style.iconTint {
            grayscale(1).colorMultiply(tint)
        } else {
            self
        }
    }
}

// MARK: - Aperçus

/// Panneau miniature dessiné avec un style : vignettes et aperçu des réglages.
/// `scale` 1 : aperçu de 360 × 190 pt (comme celui du verre).
struct StyleSample: View {
    let style: PanelStyle
    var scale: CGFloat = 1
    /// Ouverture rejouée dans Réglages › Animations.
    var shown = true
    var revealID = 0

    private static let rows: [(title: String, symbol: String, tint: Color)] = [
        ("Safari", "safari.fill", .blue),
        ("Presse-papiers", "doc.on.clipboard", .orange),
        ("Réglages Système", "gearshape.fill", .gray),
    ]

    var body: some View {
        let t = style.tokens
        let s = scale
        let radius = (t.radius ?? 26) * 0.8 * s
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        VStack(spacing: 0) {
            HStack(spacing: 8 * s) {
                mark(t)
                Text("saf")
                    .font(Font(t.displayNSFont(15 * s) as CTFont))
                Spacer(minLength: 0)
                if let button = t.iconButton {
                    Circle().fill(button.fill).frame(width: 22 * s, height: 22 * s)
                        .overlay(Image(systemName: "square.grid.3x3.fill").font(.system(size: 9 * s)).foregroundStyle(button.ink))
                }
            }
            .padding(.horizontal, 12 * s)
            .frame(height: (t.searchBar != nil ? 32 : 40) * s)
            .background { if let bar = t.searchBar { Capsule().fill(bar) } }
            .padding(.horizontal, t.searchBar != nil ? 6 * s : 0)
            .frame(height: 40 * s)
            .foregroundStyle(t.headerInk)
            .environment(\.colorScheme, t.headerDark ? .dark : .light)

            Rectangle().fill(t.divider).frame(height: 1)

            VStack(alignment: .leading, spacing: 2 * s) {
                if s >= 0.8 {
                    Text(t.sectionTitle("Récents"))
                        .font(t.sectionFont).tracking(t.sectionTracking)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8 * s)
                }
                ForEach(Array(Self.rows.prefix(s >= 0.8 ? 3 : 2).enumerated()), id: \.offset) { index, row in
                    HStack(spacing: 8 * s) {
                        SymbolTile(name: row.symbol, tint: row.tint).frame(width: 18 * s, height: 18 * s)
                            .scaleEffect(max(s, 0.6))
                        Text(row.title)
                            .font(t.fontFamily != nil ? t.font(12 * s, t.titleWeight)
                                  : .system(size: 12 * s, weight: t.titleWeight, design: t.titleDesign ?? t.design))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    .environment(\.rowSelected, index == 0)
                    .modifier(RevealItem(order: index, shown: shown, reveal: style.reveal))
                    .modifier(InkOverride(color: index == 0 ? t.selectionInk : nil))
                    .padding(.horizontal, 8 * s)
                    .frame(height: 28 * s)
                    .background {
                        if let segmented = t.segmented {
                            SegmentCard(card: segmented.card, outer: segmented.outer * s, inner: segmented.inner * s,
                                        first: index == 0, last: index == (s >= 0.8 ? 2 : 1), selected: index == 0,
                                        selectedRadius: 14 * s)
                        } else if index == 0 {
                            SelectionFill(tint: nil, radius: min(t.rowRadius, 14) * s)
                        }
                    }
                }
            }
            .padding(6 * s)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .styledPane(t, panelRadius: radius)
            .foregroundStyle(t.ink)
            .environment(\.colorScheme, t.dark ? .dark : .light)

            Rectangle().fill(t.divider).frame(height: 1)

            HStack(spacing: 6 * s) {
                Spacer()
                if s >= 0.8 { Text("Ouvrir").font(.system(size: 11, design: t.design)) }
                KeyCap("↵", primary: true).scaleEffect(min(1, s + 0.2))
            }
            .padding(.horizontal, 10 * s)
            .frame(height: 26 * s)
            .foregroundStyle(t.chromeInk)
            .environment(\.colorScheme, t.chromeDark ? .dark : .light)
        }
        .frame(width: 360 * s, height: 190 * s)
        .styledSurface(t, cornerRadius: radius)
        .background {
            if let offset = t.hardShadow {
                shape.fill(Color.black).offset(x: offset * s, y: offset * s)
            } else {
                shape.fill(Color.black.opacity(0.3)).blur(radius: 12 * s).offset(y: 8 * s)
            }
        }
        .modifier(PanelMotion(reveal: style.reveal, shown: shown, revealID: revealID))
        .environment(\.styleTokens, t)
    }

    @ViewBuilder
    private func mark(_ t: StyleTokens) -> some View {
        switch t.mark {
        case .logo:
            HelloMark(skin: t.markSkin).frame(width: 16 * scale, height: 16 * scale)
        case .symbol(let name):
            Image(systemName: name).font(.system(size: 13 * scale, weight: t.searchBar != nil ? .semibold : .regular))
                .foregroundStyle(t.searchBar != nil ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        case .prompt(let prompt):
            Text(prompt).font(.system(size: 14 * scale, weight: .bold, design: .monospaced)).foregroundStyle(t.accent)
        }
    }
}

/// Vignette d'un style dans les réglages.
struct StyleCard: View {
    let style: PanelStyle
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                ZStack {
                    StyleCard.backdrop(style)
                    StyleSample(style: style, scale: 0.3)
                }
                .frame(height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.12), lineWidth: selected ? 2.5 : 1)
                }
                Text(style.title)
                    .font(.system(size: 11.5, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(style.detail)
    }

    /// Fond derrière l'aperçu : un bureau coloré pour le verre, une surface qui va avec le style sinon.
    @ViewBuilder
    static func backdrop(_ style: PanelStyle) -> some View {
        switch style {
        case .glass:
            LinearGradient(colors: [Color(hex: "#1B1F4B"), Color(hex: "#3B1E5C"), Color(hex: "#0E3B4F")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .atelier: AtelierPalette.current.secondary
        case .glyph: AppSettings.shared.glyphAppearance == .night ? Color(hex: "#3A0B06")
            : AppSettings.shared.glyphAccent.swatch
        case .phosphor: Color(hex: "#0B130D")
        case .paper: Color(hex: "#D9CFBF")
        case .brutal: Color(hex: "#7FD1FF")
        }
    }
}

/// Pastille d'un thème de couleurs : les deux accents côte à côte, comme dans l'artifact.
struct PaletteSwatch: View {
    let palette: AtelierPalette
    let selected: Bool
    let action: () -> Void

    var body: some View {
        let colors = palette.colors
        Button(action: action) {
            VStack(spacing: 6) {
                HStack(spacing: 0) {
                    colors.primary
                    colors.secondary
                }
                .frame(width: 40, height: 40)
                .clipShape(Circle())
                .overlay(Circle().strokeBorder(Color.primary.opacity(0.12), lineWidth: 1))
                .padding(3)
                .overlay(Circle().strokeBorder(selected ? Color.primary : .clear, lineWidth: 2))
                .rotationEffect(.degrees(selected ? 90 : 0))
                .animation(StyleTokens.Atelier.spring, value: selected)
                Text(palette.title)
                    .font(.system(size: 11, weight: selected ? .semibold : .regular))
                    .foregroundStyle(selected ? .primary : .secondary)
                    .lineLimit(1)
                    .fixedSize()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
