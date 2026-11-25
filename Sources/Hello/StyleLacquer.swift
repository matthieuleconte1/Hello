import AppKit
import SwiftUI

// Laque : d'après la laque japonaise urushi et la réparation à l'or kintsugi.
//
// SOCLE (à remplacer) : ce fichier compile et branche la peau partout, avec un rendu minimal.
// Tout ce qui est propre au style vit ici. Les composants partagés l'appellent par ces points d'entrée :
// `LacquerLook` (jetons, mouvement, réglages), `LacquerDecor` et les vues `Lacquer…` (décor), `LacquerSettings` (Réglages › Apparence).

/// Variante de la peau (« Auto » suit l'apparence du Mac).
enum LacquerMode: String, CaseIterable, Identifiable {
    case auto, urushi, porcelain, cinnabar
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .urushi: "Urushi"
        case .porcelain: "Porcelaine"
        case .cinnabar: "Cinabre"
        }
    }
}

/// Ce que le décor de la peau a besoin de savoir pour se dessiner.
struct LacquerDecor {
    var dark: Bool
    var ink: Color
    var accent: Color
}

enum LacquerLook {
    static let detail = "Laque urushi et kintsugi : ébène satiné, porcelaine mate et fil d'or."
    static let symbol = "seal"
    static let summary = "glissement doux comme un paravent, un fil d'or se soude sous la recherche."
    static let effect = "glissement doux comme un paravent, un fil d'or se soude sous la recherche."

    /// Variante sombre active.
    static var isDark: Bool {
        let mode = AppSettings.shared.lacquerMode
        if mode == .auto { return StyleTokens.systemIsDark }
        return mode == .porcelain || mode == .cinnabar
    }

    /// Ce qui change l'aspect du champ de recherche (ajouter ici les réglages de la peau qui le touchent).
    static var signature: String { AppSettings.shared.lacquerMode.rawValue }

    /// « Réinitialiser l'apparence » : remet les réglages de la peau par défaut.
    static func resetSettings(_ s: AppSettings) {
        s.lacquerMode = .auto
    }

    static var tokens: StyleTokens {
        let dark = isDark
        let frame = Color(hex: dark ? "#E7E2D8" : "#0A0908")
        let pane = Color(hex: dark ? "#F5F2EB" : "#141210")
        let ink = Color(hex: dark ? "#1D1A17" : "#F0EAE0")
        let accent = Color(hex: dark ? "#AF8635" : "#D4AF63")
        return StyleTokens(
            surface: .inset(frame: frame, pane: pane),
            dark: dark, ink: ink, chromeInk: ink, chromeDark: dark,
            accent: accent, live: accent, toast: accent,
            selectionFill: Color(hex: dark ? "#EAE3D5" : "#221E18"),
            selectionInk: dark ? nil : nil,
            rowRadius: 6, cellRadius: 10, radius: 12,
            divider: ink.opacity(0.12),
            markSkin: .lacquer(ink: ink, dot: accent),
            keyFill: pane, keyInk: ink.opacity(0.8),
            primaryKeyFill: accent, primaryKeyInk: dark ? Color(hex: "#F5F2EB") : .white,
            tile: .decor,
            decor: .lacquer(LacquerDecor(dark: dark, ink: ink, accent: accent))
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
struct LacquerPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        content
            .opacity(closing ? 0.6 : 1)
            .animation(Motion.scaled(LacquerLook.close), value: closing)
            .offset(y: hidden ? -6 * Motion.amplitude : 0)
            .opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture (joué par-dessus le panneau, réglage « Effet d'ouverture »).
struct LacquerOpening: View {
    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        Color.clear.frame(width: size.width, height: size.height).allowsHitTesting(false)
    }
}

/// Fond du cadre (sous le contenu).
struct LacquerSurface: View {
    let decor: LacquerDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Fond du panneau intérieur (sous le contenu).
struct LacquerPane: View {
    let decor: LacquerDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Par-dessus le surlignage de la ligne choisie.
struct LacquerSelection: View {
    let decor: LacquerDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Par-dessus un séparateur. `role` : sous l'en-tête, au-dessus du pied de page, ou ailleurs.
struct LacquerDivider: View {
    let decor: LacquerDecor
    let vertical: Bool
    let role: StyleDivider.Role
    var body: some View { EmptyView() }
}

/// Pastille d'un symbole (recherche web, presse-papiers, réglages…).
struct LacquerTile: View {
    let decor: LacquerDecor
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
struct LacquerMarkRing: View {
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
struct LacquerMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        Circle().fill(dot).frame(width: 2 * radius, height: 2 * radius)
    }
}

/// Réglages › Apparence, quand la peau est choisie.
struct LacquerSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Variante", selection: $settings.lacquerMode) {
                ForEach(LacquerMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: { Text("Laque") }
    }
}
