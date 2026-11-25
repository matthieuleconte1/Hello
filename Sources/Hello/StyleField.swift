import AppKit
import SwiftUI

// Atelier Champ : le design system Field de Teenage Engineering (OP-1 Field, TX-6, TP-7).
// Un châssis d'aluminium microbillé sertit un plateau de touches blanches derrière un joint sombre ; quatre couleurs
// d'encodeurs (marine, havane, pierre, orange), des échelles pointillées, des libellés en minuscules, des crans.
// En noir, le châssis est anodisé mat et la ligne choisie s'allume comme une touche rétroéclairée.
//
// Ce fichier contient tout ce qui est propre au style. Les composants partagés l'appellent par ces points d'entrée :
// `FieldLook` (jetons, mouvement), `FieldDecor` et les vues `Field…` (décor), `FieldSettings` (Réglages › Apparence).

/// Fini du châssis : aluminium microbillé, noir anodisé, ou selon l'apparence du Mac (`oled` : nom historique du noir).
enum FieldFinish: String, CaseIterable, Identifiable {
    case auto, aluminium, oled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .aluminium: "Aluminium"
        case .oled: "Noir"
        }
    }
}

/// Palette de l'instrument : aluminium microbillé et touches blanches, noir anodisé et touches graphite,
/// et les quatre couleurs d'encodeurs.
enum FieldPalette {
    // Aluminium (clair) : métal froid, touches blanc cassé, joint presque noir.
    static let aluFrame = Color(hex: "#CED0D1")
    static let aluPane = Color(hex: "#F6F5F1")
    static let aluInk = Color(hex: "#17181A")
    static let aluAccent = Color(hex: "#F2541B")
    static let aluKey = Color(hex: "#F8F7F4")

    // Noir anodisé (sombre) : la ligne choisie s'allume comme une touche rétroéclairée.
    static let oledFrame = Color(hex: "#1B1C1E")
    static let oledPane = Color(hex: "#0D0E10")
    static let oledInk = Color(hex: "#EDEDEA")
    static let oledAccent = Color(hex: "#FF5A1F")
    static let oledSelection = Color(hex: "#E6E5E1")
    static let oledSelectionInk = Color(hex: "#141517")
    static let oledKeyFill = Color(hex: "#2A2B2E")

    // Encodeurs : orange, marine, havane, pierre.
    static let blue = Color(hex: "#23315C")
    static let ochre = Color(hex: "#C7A37B")
    static let titaniumLight = Color(hex: "#A6A8AA")
    static let titaniumDark = Color(hex: "#8C8F93")

    static func orange(dark: Bool) -> Color { dark ? oledAccent : aluAccent }
    static func titanium(dark: Bool) -> Color { dark ? titaniumDark : titaniumLight }

    /// Couleur d'un capuchon d'encodeur et encre de son symbole (l'ocre reste plus lisible avec une encre sombre).
    static func encoder(for name: String, dark: Bool, colored: Bool, selected: Bool) -> (fill: Color, ink: Color) {
        guard colored else {
            return selected ? (orange(dark: dark), .white) : (titanium(dark: dark), aluInk)
        }
        switch encoderIndex(for: name) {
        case 0: return (orange(dark: dark), .white)
        case 1: return (blue, .white)
        case 2: return (ochre, aluInk)
        default: return (titanium(dark: dark), aluInk)
        }
    }

    /// Hachage FNV-1a avec mélange final : chaque symbole garde toujours la même couleur, bien répartie sur les 4.
    static func encoderIndex(for name: String) -> Int {
        var hash: UInt64 = 14_695_981_039_346_656_037
        for byte in name.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }
        hash ^= hash >> 33
        hash &*= 0xff51_afd7_ed55_8ccd
        hash ^= hash >> 33
        return Int(hash % 4)
    }
}

/// Ce que le décor de Champ a besoin de savoir pour se dessiner.
struct FieldDecor {
    var dark: Bool
    var ink: Color
    var accent: Color
    var graduations: Bool
    var encoderColors: Bool
}

enum FieldLook {
    static let detail = "Aluminium microbillé, touches blanches et quatre encodeurs."
    static let symbol = "dial.medium.fill"
    static let summary = "l'instrument se met sous tension sur un ressort très amorti ; la sélection avance par crans."
    static let effect = "un VU-mètre aux quatre couleurs se calibre le long du séparateur."

    /// Fini actif (Auto suit l'apparence courante du Mac).
    static var isDark: Bool {
        switch AppSettings.shared.fieldFinish {
        case .auto: StyleTokens.systemIsDark
        case .aluminium: false
        case .oled: true
        }
    }

    static var tokens: StyleTokens {
        let p = FieldPalette.self
        let settings = AppSettings.shared
        let dark = isDark
        let ink = dark ? p.oledInk : p.aluInk
        let accent = p.orange(dark: dark)
        return StyleTokens(
            surface: .inset(frame: dark ? p.oledFrame : p.aluFrame, pane: dark ? p.oledPane : p.aluPane),
            dark: dark, ink: ink, chromeInk: ink, chromeDark: dark,
            accent: accent, accent2: p.blue, live: accent, toast: accent,
            // Aluminium : la ligne choisie devient une touche noire sérigraphiée ; Noir : une touche qui s'allume.
            selectionFill: dark ? p.oledSelection : p.aluInk,
            selectionInk: dark ? p.oledSelectionInk : p.aluPane,
            selectionBorder: nil,
            selectionBorderWidth: 1,
            rowRadius: 7, cellRadius: 10,
            radius: 14,
            border: (dark ? Color.black.opacity(0.7) : p.aluInk.opacity(0.20), 1),
            divider: .clear,
            titleWeight: .regular, searchWeight: .light, header: .lowercase,
            markSkin: .field(ink: ink, dot: accent),
            // Joint presque noir entre le châssis et le plateau de touches.
            paneBorder: dark ? Color.black : p.aluInk.opacity(0.82),
            // Bouton Applications : un poussoir rond du châssis, noir sur l'aluminium, gris anthracite sur l'OLED.
            iconButton: dark ? (p.oledKeyFill, p.oledInk) : (p.aluInk, p.aluPane),
            strongMeta: true,
            keyFill: dark ? p.oledKeyFill : p.aluKey,
            keyInk: ink.opacity(dark ? 0.85 : 0.78),
            keyBorder: dark ? Color.black.opacity(0.6) : p.aluInk.opacity(0.14),
            primaryKeyFill: accent, primaryKeyInk: .white,
            keyRaised: true, chromeLower: true,
            tile: .decor,
            // En Aluminium, les icônes d'apps sont légèrement adoucies pour s'accorder au métal mat ; pleines en OLED.
            iconSaturation: dark ? 1.0 : 0.8,
            // Pas mécanique sec : départ vif, arrêt net dans le cran.
            motion: .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.11),
            decor: .field(FieldDecor(dark: dark, ink: ink, accent: accent,
                                     graduations: settings.fieldGraduations,
                                     encoderColors: settings.fieldEncoderColors)))
    }

    /// Fond de studio qui détache le châssis : ardoise sombre derrière l'aluminium clair, béton satiné derrière l'OLED.
    @ViewBuilder static var backdrop: some View {
        if isDark {
            LinearGradient(colors: [Color(hex: "#9C9F99"), Color(hex: "#7C7F7A")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            LinearGradient(colors: [Color(hex: "#393B3F"), Color(hex: "#26282C")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    /// Mise sous tension très amortie, sans rebond tape-à-l'œil.
    static func open(light: Bool) -> Animation {
        light ? .spring(response: 0.18, dampingFraction: 0.94) : .spring(response: 0.28, dampingFraction: 0.9)
    }

    static let navigation = Animation.spring(response: 0.22, dampingFraction: 0.92)

    static func modeTransition(forward: Bool) -> AnyTransition {
        let k = Motion.amplitude
        let side: CGFloat = forward ? 1 : -1
        return .asymmetric(
            insertion: .offset(x: 16 * k * side).combined(with: .opacity),
            removal: .offset(x: -10 * k * side).combined(with: .opacity)
        )
    }

    /// Cascade courte et nette, comme des rangées qui s'allument en séquence.
    static func row(_ order: Int) -> Animation {
        .easeOut(duration: 0.13).delay(0.03 + Double(min(order, 10)) * 0.016)
    }

    static let close = Animation.easeIn(duration: 0.14)
    static var rowOffset: CGSize { CGSize(width: 0, height: 5 * Motion.amplitude) }
    static let rowScale: CGFloat = 1
}

/// Le panneau entier : mise sous tension ferme à l'ouverture et retrait propre au lancement d'une app.
struct FieldPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        let k = Motion.amplitude * (light ? 0.35 : 1)
        let close = Motion.scaled(FieldLook.close)
        content
            .scaleEffect(closing ? 1 - 0.015 * k : 1, anchor: .center)
            .animation(close, value: closing)
            .scaleEffect(hidden ? 1 - 0.022 * k : 1, anchor: .top)
            .offset(y: hidden ? -5 * k : 0)
            .opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture : un VU-mètre segmenté aux quatre couleurs se calibre le long du séparateur sous la recherche
/// (y = 60 dans le repère du panneau), tient brièvement la crête puis s'éteint en ~0,35 s.
struct MeterCalibrate: View {
    struct Values {
        var level: CGFloat = 0
        var peak: CGFloat = 0
        var opacity: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        let t = 1 / Motion.speed
        let dark = tokens.dark
        // En mode focus (panneau replié sur l'en-tête seul), le VU-mètre se pose près du bord bas.
        let y = size.height > 72 ? 60.0 : max(size.height - 4.0, 2.0)
        let inset: CGFloat = 14
        let barWidth = max(size.width - 2 * inset, 40)
        let segments = max(16, min(44, Int((barWidth / 16).rounded())))

        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay(alignment: .topLeading) {
                    if value.opacity > 0.001 {
                        FieldMeterBar(segments: segments, level: value.level, peak: value.peak, dark: dark)
                            .frame(width: barWidth, height: 3.5)
                            .offset(x: inset, y: y - 1.75)
                            .opacity(value.opacity)
                    }
                }
            } keyframes: { _ in
                KeyframeTrack(\.level) {
                    LinearKeyframe(0, duration: 0.015 * t)
                    CubicKeyframe(1.0, duration: 0.16 * t)
                    CubicKeyframe(0.14, duration: 0.095 * t)
                    LinearKeyframe(0.0, duration: 0.08 * t)
                }
                KeyframeTrack(\.peak) {
                    LinearKeyframe(0, duration: 0.015 * t)
                    CubicKeyframe(1.0, duration: 0.16 * t)
                    LinearKeyframe(1.0, duration: 0.105 * t)
                    LinearKeyframe(0.0, duration: 0.07 * t)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.02 * t)
                    LinearKeyframe(1, duration: 0.25 * t)
                    CubicKeyframe(0, duration: 0.08 * t)
                }
            }
            .allowsHitTesting(false)
    }
}

/// Barre segmentée du VU-mètre : pierre → marine → havane → orange, comme une échelle de niveau sur un instrument.
private struct FieldMeterBar: View {
    let segments: Int
    let level: CGFloat
    let peak: CGFloat
    let dark: Bool

    var body: some View {
        let peakIndex = peak > 0.05 ? min(segments - 1, Int((peak * CGFloat(segments)).rounded(.down))) : -1
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                let position = CGFloat(index + 1) / CGFloat(segments)
                let lit = position <= level || index == peakIndex
                RoundedRectangle(cornerRadius: 0.75, style: .continuous)
                    .fill(lit ? color(at: position) : (dark ? Color.white.opacity(0.07) : Color.black.opacity(0.08)))
            }
        }
        .shadow(color: dark ? FieldPalette.oledAccent.opacity(0.35) : .clear, radius: 3)
    }

    private func color(at position: CGFloat) -> Color {
        if position <= 0.28 { return FieldPalette.titanium(dark: dark) }
        if position <= 0.58 { return dark ? Color(hex: "#5B74B8") : FieldPalette.blue }
        if position <= 0.82 { return FieldPalette.ochre }
        return FieldPalette.orange(dark: dark)
    }
}

/// Motifs répétés calculés une seule fois en bitmap Retina (aucun recalcul par image).
private enum FieldTextures {
    static let scaleLight = makeScale(dark: false)
    static let scaleDark = makeScale(dark: true)

    /// Aluminium microbillé : grain isotrope serré, sans strie.
    static func bead(dark: Bool) -> NSImage {
        Grain.tile(Grain.Spec(amount: dark ? 0.085 : 0.09, lightShare: dark ? 0.8 : 1.0, specks: 0.0015,
                              seed: dark ? 0x51A7_9E23_B401_D3F7 : 0xA93C_41F0_7E2D_8B15))
    }
    static func scale(dark: Bool) -> NSImage { dark ? scaleDark : scaleLight }

    /// Échelle pointillée sérigraphiée : un point tous les 8 pt, un peu plus gros tous les cinq.
    private static func makeScale(dark: Bool) -> NSImage {
        let step = 8, count = 5, scale = 2
        return bitmapImage(width: step * count, height: 6, scale: scale) { ctx in
            for index in 0..<count {
                let major = index == 0
                let diameter: CGFloat = (major ? 2.2 : 1.5) * CGFloat(scale)
                let alpha: CGFloat = dark ? (major ? 0.42 : 0.24) : (major ? 0.55 : 0.32)
                ctx.setFillColor(CGColor(gray: dark ? 1 : 0.09, alpha: alpha))
                let cx = CGFloat(index * step) * CGFloat(scale) + CGFloat(scale)
                let cy = 3 * CGFloat(scale)
                ctx.fillEllipse(in: CGRect(x: cx - diameter / 2, y: cy - diameter / 2, width: diameter, height: diameter))
            }
        }
    }

    private static func bitmapImage(width: Int, height: Int, scale: Int, draw: (CGContext) -> Void) -> NSImage {
        let pxW = width * scale, pxH = height * scale
        guard let ctx = CGContext(data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        draw(ctx)
        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: width, height: height)) }
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
}

/// Châssis du panneau : aluminium microbillé, lumière zénithale douce et chanfrein usiné (clair en haut, sombre en bas).
struct FieldSurface: View {
    let decor: FieldDecor
    let radius: CGFloat

    var body: some View {
        let outer = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: max(radius - 1, 0), style: .continuous)
        ZStack {
            Rectangle()
                .fill(ImagePaint(image: Image(nsImage: FieldTextures.bead(dark: decor.dark))))
                .clipShape(outer)
            // Le microbillage diffuse la lumière : un très léger dégradé du haut vers le bas, jamais un reflet.
            outer.fill(LinearGradient(colors: [Color.white.opacity(decor.dark ? 0.035 : 0.20), .clear,
                                               Color.black.opacity(decor.dark ? 0.10 : 0.045)],
                                      startPoint: .top, endPoint: .bottom))

            // Chanfrein d'1 px à l'intérieur du bord usiné : reflet zénithal en haut, ombre en bas.
            inner
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(decor.dark ? 0.20 : 0.78), location: 0.0),
                            .init(color: Color.white.opacity(decor.dark ? 0.05 : 0.22), location: 0.14),
                            .init(color: .clear, location: 0.45),
                            .init(color: .clear, location: 0.72),
                            .init(color: Color.black.opacity(decor.dark ? 0.45 : 0.22), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .padding(1)
        }
        .allowsHitTesting(false)
    }
}

/// Plateau de touches serti dans le châssis : surface mate unie, arête supérieure éclairée et pied ombré,
/// comme un capuchon posé juste au-dessus du joint.
struct FieldPane: View {
    let decor: FieldDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            // Plastique mat : à peine plus clair en haut qu'en bas.
            LinearGradient(colors: [Color.white.opacity(decor.dark ? 0.025 : 0.35), .clear,
                                    Color.black.opacity(decor.dark ? 0.12 : 0.025)],
                           startPoint: .top, endPoint: .bottom)

            shape
                .inset(by: 1)
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.white.opacity(decor.dark ? 0.09 : 0.95), location: 0.0),
                            .init(color: .clear, location: 0.18),
                            .init(color: .clear, location: 0.85),
                            .init(color: Color.black.opacity(decor.dark ? 0.35 : 0.07), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

/// Voyant LED affleurant : lentille avec minuscule point spéculaire, et lueur chaude sur écran OLED.
private struct FieldLED: View {
    let color: Color
    let size: CGFloat
    let glowing: Bool

    var body: some View {
        Circle()
            .fill(color)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(glowing ? 0.6 : 0.4))
                    .frame(width: size * 0.36, height: size * 0.36)
                    .offset(x: size * 0.16, y: size * 0.16)
            }
            .frame(width: size, height: size)
            .shadow(color: glowing ? color.opacity(0.9) : .clear, radius: max(size * 0.9, 2.5))
    }
}

/// Surlignage de la ligne choisie : minuscule repère de position à gauche et voyant LED orange en haut à droite,
/// hors de la zone de texte des accessoires (qui s'arrêtent à 10 pt du bord droit, centrés verticalement).
struct FieldSelection: View {
    let decor: FieldDecor
    let radius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let tiny = height < 18
            let ledSize: CGFloat = tiny ? 2.5 : (height < 34 ? 3.5 : 4.5)
            let ledInset: CGFloat = tiny ? 2 : (height < 34 ? 4 : 4.5)
            let tickHeight = min(max(height * 0.32, 4), 14)

            ZStack {
                HStack {
                    Capsule()
                        .fill(decor.accent.opacity(decor.dark ? 0.95 : 0.9))
                        .frame(width: tiny ? 1.5 : 2, height: tickHeight)
                        .padding(.leading, tiny ? 1.5 : 3)
                    Spacer(minLength: 0)
                }

                VStack {
                    HStack {
                        Spacer(minLength: 0)
                        FieldLED(color: decor.accent, size: ledSize, glowing: decor.dark)
                            .padding(.top, ledInset)
                            .padding(.trailing, ledInset)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

/// Échelle pointillée (un point tous les 8 pt, plus gros tous les 5). Elle est sérigraphiée sur le châssis,
/// jamais sur l'écran : sous l'en-tête, elle monte dans le cadre ; au-dessus du pied de page, elle y descend.
/// Ailleurs (aperçus), un filet simple.
struct FieldDivider: View {
    let decor: FieldDecor
    let role: StyleDivider.Role

    var body: some View {
        if decor.graduations && role != .plain {
            let footer = role == .footer
            Color.clear
                .overlay(alignment: footer ? .top : .bottom) {
                    Rectangle()
                        .fill(ImagePaint(image: Image(nsImage: FieldTextures.scale(dark: decor.dark))))
                        .frame(height: 6)
                        .offset(y: footer ? 4 : -4)
                        .padding(.horizontal, 18)
                }
                .allowsHitTesting(false)
        }
    }
}

/// Capuchon d'encodeur rond dans l'une des quatre couleurs fonctionnelles (stable par symbole).
/// L'encoche tourne d'un cran (45°) à la sélection pendant que le symbole reste droit.
struct FieldTile: View {
    let decor: FieldDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        let cap = FieldPalette.encoder(for: name, dark: decor.dark, colored: decor.encoderColors, selected: selected)
        let detent = Motion.scaled(.spring(response: 0.13, dampingFraction: 0.76))

        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let showDetails = side >= 14
            // Comme sur un plateau d'encodeurs : une cuvette cerclée dans la touche, le capuchon coloré au centre.
            let capSide = showDetails ? side * 0.78 : max(side - 2, 2)

            ZStack {
                if showDetails {
                    Circle()
                        .fill(decor.dark ? Color.white.opacity(0.05) : Color.black.opacity(0.035))
                        .overlay {
                            Circle().strokeBorder(
                                LinearGradient(colors: [Color.black.opacity(decor.dark ? 0.5 : 0.16),
                                                        Color.white.opacity(decor.dark ? 0.10 : 0.8)],
                                               startPoint: .top, endPoint: .bottom),
                                lineWidth: 0.75)
                        }
                        .frame(width: side, height: side)
                }
                Circle()
                    .fill(cap.fill)
                    .overlay {
                        Circle().fill(
                            LinearGradient(
                                colors: [Color.white.opacity(0.20), .clear, Color.black.opacity(0.22)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                    .overlay {
                        // Sur sélection inversée (Aluminium) comme en OLED, le fond est sombre : filet clair sur le bord.
                        let lightRim = decor.dark || selected
                        Circle().strokeBorder(
                            lightRim ? Color.white.opacity(selected ? 0.30 : 0.16)
                                     : Color.black.opacity(0.18),
                            lineWidth: showDetails ? 0.75 : 0.5
                        )
                    }
                    .shadow(color: .black.opacity(showDetails && !decor.dark ? 0.18 : 0), radius: 0.8, y: 0.8)
                    .frame(width: capSide, height: capSide)

                // Couronne et encoche qui tournent d'un cran (45°) à la sélection.
                if showDetails {
                    ZStack {
                        Circle()
                            .inset(by: max(1.5, capSide * 0.085))
                            .stroke(cap.ink.opacity(0.16), lineWidth: 0.5)
                        VStack(spacing: 0) {
                            Capsule()
                                .fill(cap.ink.opacity(selected ? 0.96 : 0.78))
                                .frame(width: max(1.3, capSide * 0.075), height: max(2.4, capSide * 0.16))
                                .padding(.top, max(0.9, capSide * 0.055))
                            Spacer(minLength: 0)
                        }
                    }
                    .frame(width: capSide, height: capSide)
                    .rotationEffect(.degrees(selected ? 45 : 0))
                    .animation(detent, value: selected)

                    Image(systemName: name)
                        .font(.system(size: capSide * 0.42, weight: .semibold))
                        .foregroundStyle(cap.ink)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
            .scaleEffect(selected && showDetails ? 1.04 : 1)
            .animation(detent, value: selected)
        }
    }
}

/// Anneau du logo en encre de l'instrument.
struct FieldMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        MarkRing()
            .trim(from: 0, to: progress)
            .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
    }
}

/// Point du logo en voyant LED (cerclé dans l'aluminium clair, lumineux en OLED).
struct FieldMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        let dark = FieldLook.isDark
        let diameter = 2 * radius
        FieldLED(color: dot, size: diameter, glowing: dark)
            .overlay {
                if !dark {
                    Circle().strokeBorder(ink.opacity(0.18), lineWidth: max(0.5, line * 0.12))
                }
            }
    }
}

/// Réglages › Apparence, quand Atelier Champ est choisi.
struct FieldSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Fini", selection: $settings.fieldFinish) {
                ForEach(FieldFinish.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Échelles pointillées", isOn: $settings.fieldGraduations)
            Toggle("Quatre couleurs d'encodeurs", isOn: $settings.fieldEncoderColors)
        } header: {
            Text("Atelier Champ")
        } footer: {
            Text("Aluminium microbillé ou noir anodisé. Sans les quatre couleurs, les encodeurs passent en pierre et l'orange marque seul la sélection.")
        }
    }
}
