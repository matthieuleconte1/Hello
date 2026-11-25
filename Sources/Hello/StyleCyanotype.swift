import AppKit
import SwiftUI

// Cyanotype : un plan d'architecte tiré au ferroprussiate. Bleu de Prusse, papier millimétré, traits blancs nets.
// Tout est dessiné comme sur une planche : le panneau a son cartouche (double filet), ses repères de coupe aux coins,
// ses séparateurs en lignes de cote ; la ligne choisie est prise entre deux crochets de visée ; les icônes d'apps
// deviennent des dessins au trait (le détourage d'IconTrace) qui se remplissent d'un lavis une fois choisies.
//
// Ce fichier contient tout ce qui est propre au style. Les composants partagés l'appellent par ces points d'entrée :
// `CyanotypeLook` (jetons, mouvement), `CyanotypeDecor` et les vues `Cyanotype…` (décor), `CyanotypeSettings`.

/// Tirage : bleu de Prusse (le cyanotype), calque clair (le tirage diazo), selon l'apparence du Mac, ou encre de nuit.
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

    /// Le tirage effectivement affiché (« Auto » suit l'apparence du Mac).
    var resolved: CyanotypeTone {
        self == .auto ? (StyleTokens.systemIsDark ? .prussian : .tracing) : self
    }
}

/// Ce que le décor du Cyanotype a besoin de savoir pour se dessiner.
struct CyanotypeDecor {
    /// Traits blancs (ou bleus, sur calque) : repères, cotes.
    var ink: Color
    /// La couleur du traceur : crochets de visée, tracé d'ouverture.
    var accent: Color
    /// Le quadrillage millimétré, déjà à sa (faible) opacité.
    var grid: Color
    /// Grain du papier : blanc sur le bleu, bleu sur le calque.
    var grain: Color
}

enum CyanotypeLook {
    static let detail = "Tirage bleu de Prusse, quadrillage et icônes dessinées au trait."
    static let symbol = "pencil.and.ruler.fill"
    static let summary = "pas de ressort : la plume avance à vitesse constante. Le cadre et les axes se tracent, puis les "
        + "résultats arrivent de gauche à droite et les crochets de visée glissent jusqu'à la ligne choisie."
    static let effect = "la table traçante dessine le cartouche et les axes, sa plume en tête, puis l'encre s'efface."

    /// Les quatre tirages. `selection` : le bleu éclairci de la ligne choisie ; `line` : les traits de l'icône choisie,
    /// gravés dans son lavis.
    struct Palette {
        let frame, pane, ink, accent, selection, line: Color
        let dark: Bool
    }

    static func palette(_ tone: CyanotypeTone) -> Palette {
        switch tone.resolved {
        case .tracing:
            Palette(frame: Color(hex: "#DCE5F0"), pane: Color(hex: "#F4F7FB"), ink: Color(hex: "#0D316B"),
                    accent: Color(hex: "#1358C7"), selection: Color(hex: "#D5E3F6"), line: Color(hex: "#F4F7FB"), dark: false)
        case .night:
            // L'encre de nuit : tout baisse d'un cran, le blanc devient un bleu pâle qui n'éblouit pas dans le noir.
            Palette(frame: Color(hex: "#020A17"), pane: Color(hex: "#051329"), ink: Color(hex: "#93A8C7"),
                    accent: Color(hex: "#47B4D3"), selection: Color(hex: "#0C2652"), line: Color(hex: "#020A17"), dark: true)
        default:
            Palette(frame: Color(hex: "#071D40"), pane: Color(hex: "#0B2B5E"), ink: Color(hex: "#F2F7FF"),
                    accent: Color(hex: "#6CE5FF"), selection: Color(hex: "#16468F"), line: Color(hex: "#071D40"), dark: true)
        }
    }

    static var tokens: StyleTokens {
        let settings = AppSettings.shared
        let p = palette(settings.cyanotypeTone)
        let lines = settings.cyanotypeLines
        return StyleTokens(
            surface: .inset(frame: p.frame, pane: p.pane),
            dark: p.dark, ink: p.ink, chromeInk: p.ink, chromeDark: p.dark,
            accent: p.accent, accent2: p.accent, live: p.accent, toast: p.accent,
            selectionFill: p.selection,
            rowRadius: 4, cellRadius: 8, radius: 12,
            border: (p.ink.opacity(0.32), 1), divider: p.ink.opacity(0.22),
            // Futura pour la recherche, comme le lettrage des plans ; tout le reste en chasse fixe, comme les cotes.
            design: .monospaced, titleWeight: .regular, header: .blueprint,
            markSkin: .cyanotype(ink: p.ink, accent: p.accent),
            displayFamily: "Futura",
            paneBorder: p.ink.opacity(0.3), strongMeta: true,
            keyFill: .clear, keyInk: p.ink.opacity(0.75), keyBorder: p.ink.opacity(0.35),
            primaryKeyFill: p.accent, primaryKeyInk: p.frame,
            tile: .decor,
            // Au trait : l'icône n'est qu'un dessin sur un soupçon de lavis ; choisie, le lavis se remplit.
            iconTint: p.accent,
            iconOpacity: lines ? 0.16 : 0.72,
            iconOutline: lines, iconEdges: lines ? settings.cyanotypeLineDetail : nil,
            motion: .easeOut(duration: 0.14),
            iconLineSelected: p.line,
            decor: .cyanotype(CyanotypeDecor(ink: p.ink, accent: p.accent, grid: p.ink.opacity(p.dark ? 0.075 : 0.1),
                                             grain: p.ink.opacity(p.dark ? 0.05 : 0.035))))
    }

    /// Derrière la vignette : la table à dessin, un ton plus clair (ou plus sombre) que le tirage.
    @ViewBuilder static var backdrop: some View {
        switch AppSettings.shared.cyanotypeTone.resolved {
        case .tracing:
            LinearGradient(colors: [Color(hex: "#B9C8DB"), Color(hex: "#8EA3BF")], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .night:
            LinearGradient(colors: [Color(hex: "#0F1C33"), Color(hex: "#01050C")], startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            LinearGradient(colors: [Color(hex: "#2A5A9C"), Color(hex: "#0A2148")], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Mouvement

    /// Une plume ne rebondit pas : courbes sans dépassement, vitesse presque constante.
    static func open(light: Bool) -> Animation {
        light ? .easeOut(duration: 0.12) : .timingCurve(0.3, 0.05, 0.25, 1, duration: 0.3)
    }
    static let navigation = Animation.timingCurve(0.4, 0, 0.2, 1, duration: 0.22)

    static func modeTransition(forward: Bool) -> AnyTransition {
        let side: CGFloat = forward ? 1 : -1
        return .asymmetric(insertion: .offset(x: 14 * Motion.amplitude * side).combined(with: .opacity), removal: .opacity)
    }

    /// Les lignes arrivent quand la plume a fini le cadre, l'une après l'autre, en glissant de gauche à droite.
    static func row(_ order: Int) -> Animation {
        .linear(duration: 0.14).delay(0.2 + Double(min(order, 12)) * 0.03)
    }
    static let close = Animation.easeIn(duration: 0.16)
    static var rowOffset: CGSize { CGSize(width: -8 * Motion.amplitude, height: 0) }
    static let rowScale: CGFloat = 1
}

/// Le panneau entier. À l'ouverture, il se pose d'un rien vers le bas pendant que la plume trace ; au lancement d'une
/// app, il recule légèrement, comme une feuille qu'on retire de la table.
struct CyanotypePanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        let k = Motion.amplitude * (light ? 0.35 : 1)
        content
            .scaleEffect(closing ? 1 - 0.02 * k : 1)
            .animation(Motion.scaled(CyanotypeLook.close), value: closing)
            .offset(y: hidden ? -5 * k : 0)
            .opacity(hidden ? 0 : 1)
    }
}

// MARK: - Effet d'ouverture

/// La table traçante : la plume dessine le cartouche (un filet juste à l'intérieur du bord), puis les deux axes de
/// construction (le séparateur sous la recherche, la verticale du texte). Elle avance à vitesse constante, sa tête
/// en point lumineux, puis l'encre s'efface et laisse le panneau tel quel.
struct PlotterTrace: View {
    struct Values {
        var frame: CGFloat = 0
        var axes: CGFloat = 0
        var opacity: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        let t = 1 / Motion.speed
        let inset: CGFloat = 3.5
        let rect = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
        // Le cadre part du coin haut gauche, comme une plume qui commence sa planche.
        let frame = Self.frame(rect, radius: max(radius - inset, 0))
        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay(alignment: .topLeading) {
                    if value.opacity > 0.001 {
                        let drawn = frame.trimmedPath(from: 0, to: value.frame)
                        ZStack(alignment: .topLeading) {
                            drawn.stroke(tokens.accent, style: StrokeStyle(lineWidth: 1.2, lineCap: .round, lineJoin: .round))
                            Self.axes(size, progress: value.axes)
                                .stroke(tokens.accent.opacity(0.8), style: StrokeStyle(lineWidth: 1, lineCap: .round))
                            // La tête de la plume, tant qu'elle trace le cadre.
                            if value.frame > 0.001 && value.frame < 0.999, let pen = drawn.currentPoint {
                                Circle().fill(tokens.accent)
                                    .frame(width: 5, height: 5)
                                    .shadow(color: tokens.accent, radius: 4)
                                    .position(pen)
                            }
                        }
                        .opacity(value.opacity)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            } keyframes: { _ in
                KeyframeTrack(\.frame) {
                    LinearKeyframe(0, duration: 0.04 * t)
                    LinearKeyframe(1, duration: 0.42 * t)
                }
                KeyframeTrack(\.axes) {
                    LinearKeyframe(0, duration: 0.16 * t)
                    LinearKeyframe(1, duration: 0.3 * t)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.02 * t)
                    LinearKeyframe(1, duration: 0.6 * t)
                    CubicKeyframe(0, duration: 0.35 * t)
                }
            }
            .allowsHitTesting(false)
    }

    /// Le cartouche, d'un seul trait depuis le coin haut gauche, dans le sens des aiguilles d'une montre.
    private static func frame(_ rect: CGRect, radius r: CGFloat) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.minX + r, y: rect.minY))
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.maxY), radius: r)
            path.addArc(tangent1End: CGPoint(x: rect.maxX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.maxY), radius: r)
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.maxY), tangent2End: CGPoint(x: rect.minX, y: rect.minY), radius: r)
            path.addArc(tangent1End: CGPoint(x: rect.minX, y: rect.minY), tangent2End: CGPoint(x: rect.maxX, y: rect.minY), radius: r)
        }
    }

    /// L'axe horizontal sous la recherche (l'en-tête fait 60 pt) et la verticale où commence le texte recherché.
    nonisolated private static func axes(_ size: CGSize, progress p: CGFloat) -> Path {
        Path { path in
            guard p > 0.001 else { return }
            path.move(to: CGPoint(x: 0, y: 60))
            path.addLine(to: CGPoint(x: size.width * p, y: 60))
            path.move(to: CGPoint(x: 48, y: 0))
            path.addLine(to: CGPoint(x: 48, y: size.height * p))
        }
    }
}

// MARK: - Décor

/// Motifs du papier, dessinés une fois : un quadrillage millimétré et un grain. Blancs, puis teintés par
/// `colorMultiply` ; ils se répètent sans aucun calcul par image (comme `Scanlines`).
enum CyanotypePaper {
    /// Une maille de 24 pt : un trait franc, et des traits fins tous les 6 pt.
    static let grid: NSImage = NSImage(size: NSSize(width: 24, height: 24), flipped: true) { _ in
        NSColor.white.withAlphaComponent(0.3).setFill()
        for i in 1..<4 {
            let p = CGFloat(i) * 6
            NSRect(x: p, y: 0, width: 0.5, height: 24).fill()
            NSRect(x: 0, y: p, width: 24, height: 0.5).fill()
        }
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: 0.75, height: 24).fill()
        NSRect(x: 0, y: 0, width: 24, height: 0.75).fill()
        return true
    }

    /// Le grain du tirage : des points épars, de densité inégale (bruit déterministe, le même à chaque lancement).
    static let grain: NSImage = NSImage(size: NSSize(width: 96, height: 96), flipped: true) { _ in
        for y in 0..<96 {
            for x in 0..<96 {
                let n = DecodeText.noise(x, y, 11)
                guard n > 0.86 else { continue }
                NSColor.white.withAlphaComponent((n - 0.86) / 0.14).setFill()
                NSRect(x: CGFloat(x), y: CGFloat(y), width: 1, height: 1).fill()
            }
        }
        return true
    }

    static func fill(_ image: NSImage, _ color: Color) -> some View {
        Rectangle()
            .fill(ImagePaint(image: Image(nsImage: image)))
            .colorMultiply(color)
            .allowsHitTesting(false)
    }
}

/// Le cadre : le grain du tirage, et des repères de coupe aux quatre coins, comme sur une planche à massicoter.
struct CyanotypeSurface: View {
    let decor: CyanotypeDecor
    let radius: CGFloat

    var body: some View {
        ZStack {
            CyanotypePaper.fill(CyanotypePaper.grain, decor.grain)
            CropMarks(inset: 11, arm: 3.5)
                .stroke(decor.ink.opacity(0.45), lineWidth: 0.75)
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .allowsHitTesting(false)
    }
}

/// Une petite croix de repère près de chaque coin.
struct CropMarks: Shape {
    let inset: CGFloat
    let arm: CGFloat

    func path(in rect: CGRect) -> Path {
        Path { path in
            for x in [rect.minX + inset, rect.maxX - inset] {
                for y in [rect.minY + inset, rect.maxY - inset] {
                    path.move(to: CGPoint(x: x - arm, y: y))
                    path.addLine(to: CGPoint(x: x + arm, y: y))
                    path.move(to: CGPoint(x: x, y: y - arm))
                    path.addLine(to: CGPoint(x: x, y: y + arm))
                }
            }
        }
    }
}

/// Le panneau intérieur : papier millimétré, et le second filet du cartouche, à 4 pt du premier.
struct CyanotypePane: View {
    let decor: CyanotypeDecor
    let radius: CGFloat

    var body: some View {
        ZStack {
            CyanotypePaper.fill(CyanotypePaper.grid, decor.grid)
            CyanotypePaper.fill(CyanotypePaper.grain, decor.grain)
            RoundedRectangle(cornerRadius: max(radius - 4, 2), style: .continuous)
                .strokeBorder(decor.ink.opacity(0.14), lineWidth: 0.75)
                .padding(4)
        }
        .allowsHitTesting(false)
    }
}

/// Deux crochets de visée aux coins opposés de la ligne choisie. Ils suivent le surlignage (et glissent avec lui).
struct CyanotypeSelection: View {
    let decor: CyanotypeDecor
    let radius: CGFloat

    var body: some View {
        SightBrackets(arm: 8, overhang: 2.5)
            .stroke(decor.accent, style: StrokeStyle(lineWidth: 1.5, lineCap: .square, lineJoin: .miter))
            .allowsHitTesting(false)
    }
}

/// ┌ en haut à gauche, ┘ en bas à droite, posés un rien à l'extérieur du rectangle.
struct SightBrackets: Shape {
    let arm: CGFloat
    let overhang: CGFloat

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: -overhang, dy: -overhang)
        let arm = min(arm, r.height / 2)
        return Path { path in
            path.move(to: CGPoint(x: r.minX, y: r.minY + arm))
            path.addLine(to: CGPoint(x: r.minX, y: r.minY))
            path.addLine(to: CGPoint(x: r.minX + arm, y: r.minY))
            path.move(to: CGPoint(x: r.maxX - arm, y: r.maxY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
            path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - arm))
        }
    }
}

/// Le séparateur devient une ligne de cote : un petit trait d'attache à chaque bout.
struct CyanotypeDivider: View {
    let decor: CyanotypeDecor
    let vertical: Bool

    var body: some View {
        DimensionTicks(vertical: vertical, length: 7)
            .stroke(decor.ink.opacity(0.45), lineWidth: 1)
            .allowsHitTesting(false)
    }
}

/// Traits perpendiculaires aux deux extrémités d'un séparateur, débordant de part et d'autre.
struct DimensionTicks: Shape {
    let vertical: Bool
    let length: CGFloat

    func path(in rect: CGRect) -> Path {
        let half = length / 2
        return Path { path in
            if vertical {
                for y in [rect.minY + 0.5, rect.maxY - 0.5] {
                    path.move(to: CGPoint(x: rect.midX - half, y: y))
                    path.addLine(to: CGPoint(x: rect.midX + half, y: y))
                }
            } else {
                for x in [rect.minX + 0.5, rect.maxX - 0.5] {
                    path.move(to: CGPoint(x: x, y: rect.midY - half))
                    path.addLine(to: CGPoint(x: x, y: rect.midY + half))
                }
            }
        }
    }
}

/// Pastille d'un symbole, dessinée comme les icônes : un cadre et un pictogramme au trait, qui se remplissent
/// d'un lavis une fois choisis.
struct CyanotypeTile: View {
    let decor: CyanotypeDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 4, style: .continuous)
        shape
            .fill(selected ? decor.accent.opacity(0.28) : .clear)
            .overlay(shape.strokeBorder(selected ? decor.accent : decor.ink.opacity(0.5), lineWidth: 1))
            .overlay(Image(systemName: selected ? name : SymbolTile.outline(name))
                .font(.system(size: 12.5, weight: selected ? .medium : .light))
                .foregroundStyle(selected ? decor.accent : decor.ink))
            .padding(2)
            .animation(Motion.scaled(.easeOut(duration: 0.14)), value: selected)
    }
}

// MARK: - Logo

/// L'anneau au trait, comme une pièce dessinée : son contour en filet fin, et sa ligne d'axe en tirets.
struct CyanotypeMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let accent: Color

    var body: some View {
        ZStack {
            RingOutline(progress: progress, width: line)
                .stroke(ink, style: StrokeStyle(lineWidth: max(1, line * 0.2), lineJoin: .round))
            MarkRing().trim(from: 0, to: progress)
                .stroke(ink.opacity(0.55), style: StrokeStyle(lineWidth: max(0.5, line * 0.08), dash: [line * 0.5, line * 0.35]))
        }
    }
}

/// Le point devient une mire : un cercle au trait traversé par sa croix, dans la couleur du traceur.
struct CyanotypeMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let accent: Color

    var body: some View {
        let width = max(1, line * 0.2)
        ZStack {
            Circle().fill(accent.opacity(0.35))
            Circle().strokeBorder(accent, lineWidth: width)
            Path { path in
                let reach = radius * 1.7
                path.move(to: CGPoint(x: radius - reach, y: radius))
                path.addLine(to: CGPoint(x: radius + reach, y: radius))
                path.move(to: CGPoint(x: radius, y: radius - reach))
                path.addLine(to: CGPoint(x: radius, y: radius + reach))
            }
            .stroke(accent, lineWidth: width * 0.8)
        }
        .frame(width: 2 * radius, height: 2 * radius)
    }
}

// MARK: - Réglages

/// Réglages › Apparence, quand le Cyanotype est choisi.
struct CyanotypeSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Tirage", selection: $settings.cyanotypeTone) {
                ForEach(CyanotypeTone.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Icônes d'apps dessinées au trait", isOn: $settings.cyanotypeLines)
            LabeledContent("Détail des traits") {
                Slider(value: $settings.cyanotypeLineDetail, in: 0...1) { EmptyView() }
                    minimumValueLabel: { Text("Formes").font(.caption).foregroundStyle(.secondary) }
                    maximumValueLabel: { Text("Tout").font(.caption).foregroundStyle(.secondary) }
            }
            .disabled(!settings.cyanotypeLines)
        } header: { Text("Cyanotype") } footer: {
            Text("Au trait, chaque icône est détourée une fois puis gardée en cache. Choisie, elle se remplit d'un lavis.")
        }
    }
}
