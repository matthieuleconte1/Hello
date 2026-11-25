import AppKit
import SwiftUI

// Riso : d'après la risographie bichrome (encres Federal Blue et Fluorescent Pink).
//
// SOCLE (à remplacer) : ce fichier compile et branche la peau partout, avec un rendu minimal.
// Tout ce qui est propre au style vit ici. Les composants partagés l'appellent par ces points d'entrée :
// `RisoLook` (jetons, mouvement, réglages), `RisoDecor` et les vues `Riso…` (décor), `RisoSettings` (Réglages › Apparence).

/// Variante de la peau (« Auto » suit l'apparence du Mac).
enum RisoMode: String, CaseIterable, Identifiable {
    case auto, paper, anthracite
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .paper: "Papier brut"
        case .anthracite: "Anthracite"
        }
    }
}

/// Ce que le décor de la peau a besoin de savoir pour se dessiner.
struct RisoDecor {
    var dark: Bool
    var ink: Color
    var accent: Color
}

enum RisoLook {
    static let detail = "Risographie bichrome : bleu fédéral et rose fluo en surimpression, papier recyclé."
    static let symbol = "printer"
    static let summary = "la passe bleue puis la passe rose se calent à 1,5 px."
    static let effect = "la passe bleue puis la passe rose se calent à 1,5 px."

    /// Variante sombre active.
    static var isDark: Bool {
        let mode = AppSettings.shared.risoMode
        if mode == .auto { return StyleTokens.systemIsDark }
        return mode == .anthracite
    }

    /// Ce qui change l'aspect du champ de recherche (ajouter ici les réglages de la peau qui le touchent).
    static var signature: String { AppSettings.shared.risoMode.rawValue }

    /// « Réinitialiser l'apparence » : remet les réglages de la peau par défaut.
    static func resetSettings(_ s: AppSettings) {
        s.risoMode = .auto
    }

    static var tokens: StyleTokens {
        let dark = isDark
        let frame = Color(hex: dark ? "#161822" : "#EAE4D7")
        let pane = Color(hex: dark ? "#1E2130" : "#F5F1E7")
        let ink = Color(hex: dark ? "#EFEAE0" : "#1B3FA0")
        let accent = Color(hex: dark ? "#FF5EBC" : "#FF48B0")
        return StyleTokens(
            surface: .inset(frame: frame, pane: pane),
            dark: dark, ink: ink, chromeInk: ink, chromeDark: dark,
            accent: accent, live: accent, toast: accent,
            selectionFill: Color(hex: dark ? "#2D2B49" : "#FAD2E7"),
            selectionInk: dark ? nil : nil,
            rowRadius: 6, cellRadius: 10, radius: 12,
            divider: ink.opacity(0.12),
            markSkin: .riso(ink: ink, dot: accent),
            keyFill: pane, keyInk: ink.opacity(0.8),
            primaryKeyFill: accent, primaryKeyInk: dark ? Color(hex: "#1E2130") : .white,
            tile: .decor,
            decor: .riso(RisoDecor(dark: dark, ink: ink, accent: accent))
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
struct RisoPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        content
            .opacity(closing ? 0.6 : 1)
            .animation(Motion.scaled(RisoLook.close), value: closing)
            .offset(y: hidden ? -6 * Motion.amplitude : 0)
            .opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture (joué par-dessus le panneau, réglage « Effet d'ouverture »).
struct RisoOpening: View {
    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        Color.clear.frame(width: size.width, height: size.height).allowsHitTesting(false)
    }
}

/// Fond du cadre (sous le contenu).
struct RisoSurface: View {
    let decor: RisoDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Fond du panneau intérieur (sous le contenu).
struct RisoPane: View {
    let decor: RisoDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Par-dessus le surlignage de la ligne choisie.
struct RisoSelection: View {
    let decor: RisoDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

/// Par-dessus un séparateur. `role` : sous l'en-tête, au-dessus du pied de page, ou ailleurs.
struct RisoDivider: View {
    let decor: RisoDecor
    let vertical: Bool
    let role: StyleDivider.Role
    var body: some View { EmptyView() }
}

/// Pastille d'un symbole (recherche web, presse-papiers, réglages…).
struct RisoTile: View {
    let decor: RisoDecor
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
struct RisoMarkRing: View {
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
struct RisoMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        Circle().fill(dot).frame(width: 2 * radius, height: 2 * radius)
    }
}

/// Réglages › Apparence, quand la peau est choisie.
struct RisoSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Variante", selection: $settings.risoMode) {
                ForEach(RisoMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        } header: { Text("Riso") }
    }
}
