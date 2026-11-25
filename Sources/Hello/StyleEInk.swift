import AppKit
import SwiftUI

// E-Encre : d'après les liseuses à encre électronique et la tablette reMarkable.
//
// SOCLE (à remplacer) : ce fichier compile et branche la peau partout, avec un rendu minimal.
// Tout ce qui est propre au style vit ici. Les composants partagés l'appellent par ces points d'entrée :
// `EInkLook` (jetons, mouvement, réglages), `EInkDecor` et les vues `EInk…` (décor), `EInkSettings` (Réglages › Apparence).

/// Variante de la peau (« Auto » suit l'apparence du Mac).
enum EInkMode: String, CaseIterable, Identifiable {
    case auto, day, night
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .day: "Jour"
        case .night: "Nuit"
        }
    }
}

/// Ce que le décor de la peau a besoin de savoir pour se dessiner.
struct EInkDecor {
    var dark: Bool
    var ink: Color
    var accent: Color
}

enum EInkLook {
    static let detail = "Dalle à encre électronique : gris minéral, contraste mat, icônes tramées."
    static let symbol = "book.pages"
    static let summary = "un flash d'inversion façon rafraîchissement e-ink, puis plus aucune animation."
    static let effect = "un flash d'inversion façon rafraîchissement e-ink, puis plus aucune animation."

    /// Variante sombre active.
    static var isDark: Bool {
        let mode = AppSettings.shared.einkMode
        if mode == .auto { return StyleTokens.systemIsDark }
        return mode == .night
    }

    /// Ce qui change l'aspect du champ de recherche (ajouter ici les réglages de la peau qui le touchent).
    static var signature: String { AppSettings.shared.einkMode.rawValue }

    /// « Réinitialiser l'apparence » : remet les réglages de la peau par défaut.
    static func resetSettings(_ s: AppSettings) {
        s.einkMode = .auto
    }

    static var tokens: StyleTokens {
        let dark = isDark
        let frame = Color(hex: dark ? "#1F201D" : "#CECFCA")
        let pane = Color(hex: dark ? "#151614" : "#E5E6E1")
        let ink = Color(hex: dark ? "#DCDDD8" : "#141414")
        let accent = Color(hex: dark ? "#DCDDD8" : "#141414")
        return StyleTokens(
            surface: .inset(frame: frame, pane: pane),
            dark: dark, ink: ink, chromeInk: ink, chromeDark: dark,
            accent: accent, live: accent, toast: accent,
            selectionFill: Color(hex: dark ? "#DCDDD8" : "#141414"),
            selectionInk: dark ? Color(hex: "#151614") : Color(hex: "#E5E6E1"),
            rowRadius: 6, cellRadius: 10, radius: 12,
            divider: ink.opacity(0.12),
            markSkin: .eink(ink: ink, dot: accent),
            keyFill: pane, keyInk: ink.opacity(0.8),
            primaryKeyFill: accent, primaryKeyInk: dark ? Color(hex: "#151614") : .white,
            tile: .decor,
            decor: .eink(EInkDecor(dark: dark, ink: ink, accent: accent))
        )
    }

    /// Fond derrière la vignette de la peau (Réglages et aperçus).
    @ViewBuilder static var backdrop: some View {
        LinearGradient(colors: isDark ? [Color(hex: "#2A2B2E"), Color(hex: "#0E0F11")]
                                      : [Color(hex: "#C9CACC"), Color(hex: "#8E9094")],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    // MARK: Mouvement

    static func open(light: Bool) -> Animation { light ? .easeOut(duration: 0.14) : .easeOut(duration: 0.24) }
    static let navigation = Animation.easeOut(duration: 0.18)
    static func modeTransition(forward: Bool) -> AnyTransition { .opacity }
    static func row(_ order: Int) -> Animation { .easeOut(duration: 0.2).delay(0.04 + Double(min(order, 12)) * 0.025) }
    static let close = Animation.easeIn(duration: 0.16)
    static var rowOffset: CGSize { CGSize(width: 0, height: 6 * Motion.amplitude) }
    static let rowScale: CGFloat = 1
}

/// Le panneau entier à l'ouverture et au lancement d'une app.
struct EInkPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        content
            .opacity(closing ? 0.6 : 1)
            .animation(Motion.scaled(EInkLook.close), value: closing)
            .offset(y: hidden ? -6 * Motion.amplitude : 0)
            .opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture (joué par-dessus le panneau, réglage « Effet d'ouverture »).
struct EInkOpening: View {
    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        Color.clear.frame(width: size.width, height: size.height).allowsHitTesting(false)
    }
}

/// Fond du cadre (sous le contenu).
struct EInkSurface: View {
    let decor: EInkDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Fond du panneau intérieur (sous le contenu).
struct EInkPane: View {
    let decor: EInkDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Par-dessus le surlignage de la ligne choisie.
struct EInkSelection: View {
    let decor: EInkDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Par-dessus un séparateur. `role` : sous l'en-tête, au-dessus du pied de page, ou ailleurs.
struct EInkDivider: View {
    let decor: EInkDecor
    let vertical: Bool
    let role: StyleDivider.Role
    var body: some View { EmptyView() }
}

/// Pastille d'un symbole (recherche web, presse-papiers, réglages…).
struct EInkTile: View {
    let decor: EInkDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .fill(selected ? decor.accent : decor.ink.opacity(0.08))
            .overlay(Image(systemName: name).font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(selected ? Color.white : decor.ink))
            .padding(1.5)
    }
}

/// Anneau du logo.
struct EInkMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        MarkRing().trim(from: 0, to: progress)
            .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
    }
}

/// Point du logo.
struct EInkMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        Circle().fill(dot).frame(width: 2 * radius, height: 2 * radius)
    }
}

/// Réglages › Apparence, quand la peau est choisie.
struct EInkSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Variante", selection: $settings.einkMode) {
                ForEach(EInkMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: { Text("E-Encre") }
    }
}
