import AppKit
import SwiftUI

// Cyanotype : un plan d'architecte tiré au ferroprussiate. Bleu de Prusse, quadrillage, traits blancs.
//
// Ce fichier contient tout ce qui est propre au style. Les composants partagés l'appellent par ces points d'entrée :
// `CyanotypeLook` (jetons, mouvement), `CyanotypeDecor` et les vues `Field…` (décor), `CyanotypeSettings` (Réglages › Apparence).

/// Tirage : bleu de Prusse (le cyanotype), calque clair (le diazo), selon l'apparence du Mac, ou encre de nuit.
enum CyanotypeTone: String, CaseIterable, Identifiable {
    case prussian, tracing, auto, night
    var id: String { rawValue }
    var title: String {
        switch self {
        case .prussian: "Bleu de Prusse"
        case .tracing: "Calque"
        case .auto: "Auto"
        case .night: "Encre de nuit"
        }
    }
}

/// Ce que le décor de Champ a besoin de savoir pour se dessiner.
struct CyanotypeDecor {
    var ink: Color
}

enum CyanotypeLook {
    static let detail = "Châssis d'aluminium, écran encastré et quatre encodeurs."
    static let symbol = "dial.medium.fill"
    static let summary = "l'instrument se met sous tension sur un ressort très amorti ; la sélection avance par crans."
    static let effect = "un VU-mètre aux quatre couleurs se calibre le long du séparateur."

    static var tokens: StyleTokens {
        let ink = Color(hex: "#17181A")
        return StyleTokens(
            surface: .inset(frame: Color(hex: "#D6D7D2"), pane: Color(hex: "#EEEEEA")),
            dark: false, ink: ink, chromeInk: ink, chromeDark: false,
            accent: Color(hex: "#F05023"), live: Color(hex: "#F05023"), toast: Color(hex: "#F05023"),
            selectionFill: ink, selectionInk: Color(hex: "#EEEEEA"), rowRadius: 6, cellRadius: 12,
            radius: 14, divider: ink.opacity(0.12),
            markSkin: .cyanotype(ink: ink, accent: Color(hex: "#F05023")),
            keyFill: .clear, keyInk: ink.opacity(0.7), keyBorder: ink.opacity(0.25),
            motion: .easeOut(duration: 0.11),
            decor: .cyanotype(CyanotypeDecor(ink: ink)))
    }

    static var backdrop: some View { Color(hex: "#9EA09A") }

    static func open(light: Bool) -> Animation {
        light ? .spring(response: 0.2, dampingFraction: 0.9) : .spring(response: 0.28, dampingFraction: 0.9)
    }
    static let navigation = Animation.easeOut(duration: 0.16)
    static func modeTransition(forward: Bool) -> AnyTransition { .opacity }
    static func row(_ order: Int) -> Animation { .easeOut(duration: 0.18).delay(0.05 + Double(min(order, 12)) * 0.025) }
    static let close = Animation.easeIn(duration: 0.16)
    static var rowOffset: CGSize { CGSize(width: 0, height: 6 * Motion.amplitude) }
    static let rowScale: CGFloat = 1
}

/// Le panneau entier : ouverture et effacement au lancement d'une app.
struct CyanotypePanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        content.opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture (Réglages › Animations › « Effet d'ouverture »).
struct PlotterTrace: View {
    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View { EmptyView() }
}

struct CyanotypeSurface: View {
    let decor: CyanotypeDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

struct CyanotypePane: View {
    let decor: CyanotypeDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

struct CyanotypeSelection: View {
    let decor: CyanotypeDecor
    let radius: CGFloat
    var body: some View { EmptyView() }
}

struct CyanotypeDivider: View {
    let decor: CyanotypeDecor
    let vertical: Bool
    var body: some View { EmptyView() }
}

struct CyanotypeTile: View {
    let decor: CyanotypeDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        Circle().fill(tint).overlay(Image(systemName: name).font(.system(size: 12, weight: .semibold)).foregroundStyle(.white))
    }
}

struct CyanotypeMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let accent: Color

    var body: some View {
        MarkRing().trim(from: 0, to: progress).stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
    }
}

struct CyanotypeMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let accent: Color

    var body: some View { Circle().fill(accent).frame(width: 2 * radius, height: 2 * radius) }
}

/// Réglages › Apparence, quand Atelier Champ est choisi.
struct CyanotypeSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section("Cyanotype") {
            Picker("Tirage", selection: $settings.cyanotypeTone) {
                ForEach(CyanotypeTone.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
        }
    }
}
