import AppKit
import SwiftUI

// Atelier Champ : le design system Field de Teenage Engineering (OP-1 Field, TX-6, TP-7).
// Un châssis d'aluminium anodisé encadre un écran mat ; quatre couleurs d'encodeurs, des graduations, des crans.
//
// Ce fichier contient tout ce qui est propre au style. Les composants partagés l'appellent par ces points d'entrée :
// `FieldLook` (jetons, mouvement), `FieldDecor` et les vues `Field…` (décor), `FieldSettings` (Réglages › Apparence).

/// Fini du châssis : aluminium clair, écran OLED sur châssis noir, ou selon l'apparence du Mac.
enum FieldFinish: String, CaseIterable, Identifiable {
    case auto, aluminium, oled
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .aluminium: "Aluminium"
        case .oled: "OLED"
        }
    }
}

/// Palette de l'instrument : aluminium anodisé clair, alu noir sur écran OLED, et les quatre couleurs d'encodeurs.
enum FieldPalette {
    // Aluminium (clair)
    static let aluFrame = Color(hex: "#D6D7D2")
    static let aluPane = Color(hex: "#EEEEEA")
    static let aluInk = Color(hex: "#17181A")
    static let aluAccent = Color(hex: "#F05023")

    // OLED (sombre)
    static let oledFrame = Color(hex: "#1E1F22")
    static let oledPane = Color(hex: "#0E0F11")
    static let oledInk = Color(hex: "#F0F0EC")
    static let oledAccent = Color(hex: "#FF5722")
    static let oledSelection = Color(hex: "#1D2025")
    static let oledKeyFill = Color(hex: "#2A2C31")

    // Encodeurs : orange, bleu, ocre, gris titane.
    static let blue = Color(hex: "#2B6CF6")
    static let ochre = Color(hex: "#E09B24")
    static let titaniumLight = Color(hex: "#6F7379")
    static let titaniumDark = Color(hex: "#7D828A")

    static func orange(dark: Bool) -> Color { dark ? oledAccent : aluAccent }
    static func titanium(dark: Bool) -> Color { dark ? titaniumDark : titaniumLight }

    /// Couleur d'un capuchon d'encodeur et encre de son symbole (l'ocre reste plus lisible avec une encre sombre).
    static func encoder(for name: String, dark: Bool, colored: Bool, selected: Bool) -> (fill: Color, ink: Color) {
        guard colored else {
            return selected ? (orange(dark: dark), .white) : (titanium(dark: dark), .white)
        }
        switch encoderIndex(for: name) {
        case 0: return (orange(dark: dark), .white)
        case 1: return (blue, .white)
        case 2: return (ochre, aluInk)
        default: return (titanium(dark: dark), .white)
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
    static let detail = "Châssis d'aluminium, écran encastré et quatre encodeurs."
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
            selectionFill: dark ? p.oledSelection : p.aluInk,
            selectionInk: dark ? nil : p.aluPane,
            // En OLED, un filet discret : le repère orange et la LED portent seuls l'accent, comme sur une façade.
            selectionBorder: dark ? Color.white.opacity(0.16) : nil,
            selectionBorderWidth: 1,
            rowRadius: 6, cellRadius: 10,
            radius: 14,
            border: (dark ? Color.black.opacity(0.65) : p.aluInk.opacity(0.18), 1),
            divider: dark ? Color.white.opacity(0.10) : p.aluInk.opacity(0.13),
            titleWeight: .medium, searchWeight: .medium, header: .label,
            markSkin: .field(ink: ink, dot: accent),
            paneBorder: dark ? Color.white.opacity(0.09) : p.aluInk.opacity(0.14),
            // Bouton Applications : un poussoir rond du châssis, noir sur l'aluminium, gris anthracite sur l'OLED.
            iconButton: dark ? (p.oledKeyFill, p.oledInk) : (p.aluInk, p.aluPane),
            strongMeta: true,
            keyFill: dark ? p.oledKeyFill : p.aluPane,
            keyInk: ink.opacity(dark ? 0.85 : 0.82),
            keyBorder: dark ? Color.white.opacity(0.14) : p.aluInk.opacity(0.22),
            primaryKeyFill: accent, primaryKeyInk: .white,
            monoKeys: true, chromeCaps: true,
            sectionRule: dark ? Color.white.opacity(0.10) : p.aluInk.opacity(0.10),
            tile: .decor,
            // En Aluminium, les icônes d'apps sont légèrement adoucies pour s'accorder au métal mat ; pleines en OLED.
            iconSaturation: dark ? 1.0 : 0.74,
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

/// Barre segmentée du VU-mètre : titane → bleu → ocre → orange, comme une échelle de niveau sur un instrument.
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
        if position <= 0.58 { return FieldPalette.blue }
        if position <= 0.82 { return FieldPalette.ochre }
        return FieldPalette.orange(dark: dark)
    }
}

/// Motifs répétés calculés une seule fois en bitmap Retina (aucun recalcul par image).
private enum FieldTextures {
    static let brushedLight = makeBrushed(dark: false)
    static let brushedDark = makeBrushed(dark: true)
    static let gridLight = makeGrid(dark: false)
    static let gridDark = makeGrid(dark: true)
    static let rulerLight = makeRuler(dark: false)
    static let rulerDark = makeRuler(dark: true)

    static func brushed(dark: Bool) -> NSImage { dark ? brushedDark : brushedLight }
    static func grid(dark: Bool) -> NSImage { dark ? gridDark : gridLight }
    static func ruler(dark: Bool) -> NSImage { dark ? rulerDark : rulerLight }

    /// Grain d'aluminium brossé horizontal très discret : fines stries déterministes d'un pixel.
    private static func makeBrushed(dark: Bool) -> NSImage {
        let width = 128, height = 64, scale = 2
        return bitmapImage(width: width, height: height, scale: scale) { ctx in
            var seed: UInt64 = dark ? 0x51A7_9E23_B401_D3F7 : 0xA93C_41F0_7E2D_8B15
            for y in 0..<(height * scale) {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let bright = (seed >> 33) & 1 == 0
                let strength = Double((seed >> 40) & 0xFF) / 255.0
                let alpha = (dark ? 0.022 : 0.036) * (0.25 + 0.75 * strength)
                ctx.setFillColor(CGColor(gray: bright ? 1 : 0, alpha: alpha))
                ctx.fill(CGRect(x: 0, y: y, width: width * scale, height: 1))
            }
        }
    }

    /// Micro-trame de points (16 × 16 pt) sur le fond de l'écran encastré.
    private static func makeGrid(dark: Bool) -> NSImage {
        let side = 16, scale = 2
        let center = CGFloat(side * scale) / 2
        return bitmapImage(width: side, height: side, scale: scale) { ctx in
            ctx.setFillColor(CGColor(gray: dark ? 1 : 0, alpha: dark ? 0.065 : 0.055))
            ctx.fill(CGRect(x: center, y: center, width: 1.5, height: 1.5))
        }
    }

    /// Graduations de règle : 3 pt tous les 8 pt, et un repère de 5,5 pt tous les 5 traits (pas de 40 pt).
    private static func makeRuler(dark: Bool) -> NSImage {
        let step = 8, count = 5, scale = 2
        return bitmapImage(width: step * count, height: 6, scale: scale) { ctx in
            let gray: CGFloat = dark ? 1 : 0.09
            for index in 0..<count {
                let major = index == 0
                let tickLength: CGFloat = major ? 5.5 : 3.0
                let alpha: CGFloat = dark ? (major ? 0.38 : 0.18) : (major ? 0.40 : 0.20)
                ctx.setFillColor(CGColor(gray: gray, alpha: alpha))
                let offset = CGFloat(index * step) * CGFloat(scale)
                let length = tickLength * CGFloat(scale)
                // En coordonnées CGContext (y = 0 en bas), les traits partent du filet et montent dans le cadre.
                ctx.fill(CGRect(x: offset, y: 0, width: CGFloat(scale), height: length))
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

/// Châssis du panneau : grain d'aluminium brossé et chanfrein usiné (filet clair en haut, sombre en bas).
struct FieldSurface: View {
    let decor: FieldDecor
    let radius: CGFloat

    var body: some View {
        let outer = RoundedRectangle(cornerRadius: radius, style: .continuous)
        let inner = RoundedRectangle(cornerRadius: max(radius - 1, 0), style: .continuous)
        ZStack {
            Rectangle()
                .fill(ImagePaint(image: Image(nsImage: FieldTextures.brushed(dark: decor.dark))))
                .clipShape(outer)

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

/// Écran intérieur encastré dans le châssis : micro-trame et chanfrein concave (ombre en haut, lèvre éclairée en bas).
struct FieldPane: View {
    let decor: FieldDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            if decor.graduations {
                Rectangle()
                    .fill(ImagePaint(image: Image(nsImage: FieldTextures.grid(dark: decor.dark))))
            }

            // Légère ombre portée du rebord supérieur du châssis sur l'écran encastré.
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [Color.black.opacity(decor.dark ? 0.40 : 0.07), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 5)
                Spacer(minLength: 0)
            }

            shape
                .strokeBorder(
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(decor.dark ? 0.55 : 0.14), location: 0.0),
                            .init(color: .clear, location: 0.22),
                            .init(color: .clear, location: 0.80),
                            .init(color: Color.white.opacity(decor.dark ? 0.10 : 0.65), location: 1.0),
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

/// Séparateur gradué comme une règle (3 pt, repère plus long tous les 5 traits). L'échelle est gravée sur le châssis,
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
                        .fill(ImagePaint(image: Image(nsImage: FieldTextures.ruler(dark: decor.dark))))
                        .frame(height: 6)
                        .scaleEffect(y: footer ? -1 : 1)
                        .padding(.horizontal, 16)
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
            let inset: CGFloat = side > 12 ? 1 : 0
            let capSide = max(side - 2 * inset, 2)
            let showDetails = capSide >= 12

            ZStack {
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
                    .rotationEffect(.degrees(selected ? 45 : 0))
                    .animation(detent, value: selected)

                    Image(systemName: name)
                        .font(.system(size: capSide * 0.40, weight: .semibold))
                        .foregroundStyle(cap.ink)
                }
            }
            .frame(width: capSide, height: capSide)
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
            Toggle("Graduations millimétrées", isOn: $settings.fieldGraduations)
            Toggle("Quatre couleurs d'encodeurs", isOn: $settings.fieldEncoderColors)
        } header: {
            Text("Atelier Champ")
        } footer: {
            Text("Châssis d'aluminium anodisé clair ou noir OLED. Sans les quatre couleurs, les encodeurs passent en titane et l'orange marque seul la sélection.")
        }
    }
}
