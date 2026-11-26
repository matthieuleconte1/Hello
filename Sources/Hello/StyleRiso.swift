import AppKit
import SwiftUI

// Riso : risographie bichrome, l'imprimerie artisanale.
// Papier recyclé texturé (grain ~4 %, fibres et mouchetures), aucun noir pur : encre Bleu Fédéral et Rose Fluo
// en surimpression (multiply sur papier brut, screen sur anthracite, faisant naître un violet au chevauchement).
// La sélection décale l'aplat rose de 2 × 1,5 pt par rapport au contour bleu net sans jamais décaler le texte.
//
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

/// Palette bichrome risographique (aucun noir pur).
enum RisoPalette {
    // Papier brut (clair) : papier recyclé chaud, encre Bleu Fédéral, Rose Fluo.
    static let paperFrame = Color(hex: "#EAE4D7")
    static let paperPane = Color(hex: "#F5F1E7")
    static let paperInk = Color(hex: "#1B3FA0")
    static let paperSecondary = Color(hex: "#5E77BD")
    static let paperPink = Color(hex: "#FF48B0")
    static let paperKey = Color(hex: "#EFEADE")

    // Anthracite (sombre) : carton anthracite, texte crème chaud, Bleu électrique et Rose Fluo.
    static let darkFrame = Color(hex: "#161822")
    static let darkPane = Color(hex: "#1E2130")
    static let darkInk = Color(hex: "#EFEAE0")
    static let darkSecondary = Color(hex: "#939EC2")
    static let darkPink = Color(hex: "#FF5EBC")
    static let darkBlue = Color(hex: "#3AD5FF")
    static let darkKey = Color(hex: "#25293B")

    static func blue(dark: Bool) -> Color { dark ? darkBlue : paperInk }
    static func pink(dark: Bool) -> Color { dark ? darkPink : paperPink }
    static func secondary(dark: Bool) -> Color { dark ? darkSecondary : paperSecondary }
}

/// Ce que le décor de la peau a besoin de savoir pour se dessiner.
struct RisoDecor {
    var dark: Bool
    var ink: Color
    var blue: Color
    var accent: Color
    var secondary: Color
    var halftone: Bool
    var grain = true
}

enum RisoLook {
    static let detail = "Risographie bichrome : bleu fédéral et rose fluo en surimpression, papier recyclé."
    static let symbol = "printer"
    static let summary = "double passe d'imprimerie : la passe bleue se cale puis la passe rose vient s'aligner à 1,5 pt en 280 ms."
    static let effect = "la passe bleue puis la passe rose tramée se calent à 1,5 pt l'une de l'autre."

    /// Variante sombre active.
    static var isDark: Bool {
        let mode = AppSettings.shared.risoMode
        if mode == .auto { return StyleTokens.systemIsDark }
        return mode == .anthracite
    }

    /// Ce qui change l'aspect du champ de recherche.
    static var signature: String {
        let s = AppSettings.shared
        return "\(s.risoMode.rawValue)|\(s.risoHalftone)|\(s.risoDuotoneIcons)|\(s.risoGrain)"
    }

    /// « Réinitialiser l'apparence » : remet les réglages de la peau par défaut.
    static func resetSettings(_ s: AppSettings) {
        s.risoMode = .auto
        s.risoHalftone = true
        s.risoDuotoneIcons = true
        s.risoGrain = true
    }

    static var tokens: StyleTokens {
        let p = RisoPalette.self
        let settings = AppSettings.shared
        let dark = isDark
        let frame = dark ? p.darkFrame : p.paperFrame
        let pane = dark ? p.darkPane : p.paperPane
        let ink = dark ? p.darkInk : p.paperInk
        let blue = p.blue(dark: dark)
        let pink = p.pink(dark: dark)
        let secondary = p.secondary(dark: dark)

        // Sur papier brut, vraie bichromie sans aucun noir pur via `IconPhotogram(dark: false, glow: .clear)`.
        // Sur anthracite, teinte bleu électrique nette sur le carton sombre.
        let iconPhotogram: StyleTokens.IconPhotogram? = (!dark && settings.risoDuotoneIcons)
            ? StyleTokens.IconPhotogram(dark: false, tint: p.paperInk, highlight: p.paperInk, glow: .clear)
            : nil

        return StyleTokens(
            surface: .inset(frame: frame, pane: pane),
            dark: dark,
            ink: ink,
            chromeInk: ink,
            chromeDark: dark,
            accent: pink,
            accent2: blue,
            live: pink,
            toast: pink,
            // La sélection est rendue par `RisoSelection` : aplat rose décalé 2 × 1,5 pt + contour bleu net.
            selectionFill: .clear,
            // Sous-titres et accessoires à pleine encre sur l'aplat rose : lisibles, sans gris délavé.
            selectionInk: ink,
            selectionBorder: nil,
            rowRadius: 8,
            cellRadius: 11,
            radius: 17,
            border: (blue.opacity(dark ? 0.88 : 0.95), 1.5),
            hardShadow: 5,
            hardShadowColor: pink.opacity(dark ? 0.45 : 0.48),
            // Pas de filet doublon au-dessus du panneau intérieur : `paneBorder` et `RisoDivider` portent le repère.
            divider: .clear,
            design: .default,
            titleWeight: .semibold,
            searchWeight: .bold,
            header: .label,
            markSkin: .riso(ink: blue, dot: pink),
            fontFamily: "Avenir Next",
            displayFamily: "American Typewriter",
            paneBorder: blue.opacity(dark ? 0.34 : 0.32),
            iconButton: (fill: blue, ink: dark ? p.darkFrame : p.paperPane),
            strongMeta: true,
            keyFill: dark ? p.darkKey : p.paperKey,
            keyInk: dark ? p.darkInk.opacity(0.92) : p.paperInk.opacity(0.92),
            keyBorder: blue.opacity(dark ? 0.40 : 0.36),
            primaryKeyFill: pink,
            primaryKeyInk: dark ? p.darkFrame : p.paperPane,
            monoKeys: true,
            sectionRule: pink.opacity(dark ? 0.42 : 0.46),
            launchTint: pink,
            tile: .decor,
            iconTint: (dark && settings.risoDuotoneIcons) ? blue : nil,
            iconSaturation: settings.risoDuotoneIcons ? 1.0 : 0.82,
            motion: .timingCurve(0.22, 0.9, 0.3, 1, duration: 0.14),
            iconPhotogram: iconPhotogram,
            decor: .riso(RisoDecor(
                dark: dark,
                ink: ink,
                blue: blue,
                accent: pink,
                secondary: secondary,
                halftone: settings.risoHalftone,
                grain: settings.risoGrain
            ))
        )
    }

    /// Fond de table d'atelier qui met en valeur le papier recyclé et son ombre rose pleine.
    @ViewBuilder static var backdrop: some View {
        if isDark {
            LinearGradient(
                colors: [Color(hex: "#272B3E"), Color(hex: "#11131C")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else {
            LinearGradient(
                colors: [Color(hex: "#C5CEE0"), Color(hex: "#98A7C8")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: Mouvement

    /// Double passe nerveuse et nette (~280 ms).
    static func open(light: Bool) -> Animation {
        light ? .easeOut(duration: 0.14) : .spring(response: 0.3, dampingFraction: 0.72)
    }

    static let navigation = Animation.timingCurve(0.24, 0.88, 0.3, 1, duration: 0.18)

    static func modeTransition(forward: Bool) -> AnyTransition {
        let k = Motion.amplitude
        let side: CGFloat = forward ? 1 : -1
        return .asymmetric(
            insertion: .offset(x: 14 * k * side).combined(with: .opacity),
            removal: .offset(x: -8 * k * side).combined(with: .opacity)
        )
    }

    static func row(_ order: Int) -> Animation {
        .spring(response: 0.26, dampingFraction: 0.78).delay(0.08 + Double(min(order, 12)) * 0.03)
    }

    static let close = Animation.easeIn(duration: 0.15)
    static var rowOffset: CGSize { CGSize(width: -9 * Motion.amplitude, height: 5 * Motion.amplitude) }
    static let rowScale: CGFloat = 1
}

// MARK: - Mouvement du panneau et effet d'ouverture (double passe)

/// Le panneau entier : léger calage de presse à l'ouverture, et appui net vers l'ombre rose au lancement.
struct RisoPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        let k = Motion.amplitude * (light ? 0.35 : 1)
        // La feuille entre dans la presse de travers et décalée, puis se cale d'un coup sec sur les taquets.
        content
            .offset(x: closing ? 3 * k : 0, y: closing ? 3 * k : 0)
            .opacity(closing ? 0.72 : 1)
            .animation(Motion.scaled(RisoLook.close), value: closing)
            .rotationEffect(.degrees(hidden ? -1.2 * k : 0), anchor: .topLeading)
            .offset(x: hidden ? -10 * k : 0, y: hidden ? -14 * k : 0)
            .opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture : double passe d'imprimerie en ~280 ms.
/// La passe bleue se cale d'abord sur le cadre, puis la passe rose tramée glisse se caler à 1,5 pt
/// en créant une brève surimpression violette, avant de s'effacer proprement.
struct RisoOpening: View {
    struct Values {
        var blueShift: CGFloat = 1
        var pinkShift: CGFloat = 1
        var blueOpacity: Double = 0
        var pinkOpacity: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        let t = 1 / Motion.speed
        let amp = min(max(Motion.amplitude, 0.45), 1.4)
        let dark = tokens.dark
        let blue = RisoPalette.blue(dark: dark)
        let pink = RisoPalette.pink(dark: dark)
        let blend: BlendMode = dark ? .screen : .multiply
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)

        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay {
                    if value.blueOpacity > 0.002 || value.pinkOpacity > 0.002 {
                        ZStack {
                            // Passe 1 : Bleu Fédéral / Bleu électrique qui se cale en (0, 0).
                            if value.blueOpacity > 0.002 {
                                shape
                                    .strokeBorder(blue, lineWidth: 2)
                                    .offset(x: -12 * amp * value.blueShift, y: -8 * amp * value.blueShift)
                                    .opacity(value.blueOpacity)
                                    .blendMode(blend)
                            }
                            // Passe 2 : Rose Fluo tramé qui vient se caler à (1,5 ; 1,5) pt de la passe bleue.
                            if value.pinkOpacity > 0.002 {
                                let dx = 1.5 + 16 * amp * value.pinkShift
                                let dy = 1.5 + 11 * amp * value.pinkShift
                                ZStack {
                                    shape
                                        .fill(pink.opacity(dark ? 0.14 : 0.12))
                                    if AppSettings.shared.risoHalftone {
                                        Rectangle()
                                            .fill(ImagePaint(image: Image(nsImage: RisoTextures.halftone)))
                                            .colorMultiply(pink)
                                            .opacity(dark ? 0.24 : 0.20)
                                            .clipShape(shape)
                                    }
                                    shape
                                        .strokeBorder(pink, lineWidth: 1.5)
                                }
                                .offset(x: dx, y: dy)
                                .opacity(value.pinkOpacity)
                                .blendMode(blend)
                            }
                        }
                        .clipShape(shape)
                    }
                }
            } keyframes: { _ in
                // Passe bleue : arrive et se cale en ~140 ms.
                KeyframeTrack(\.blueShift) {
                    LinearKeyframe(1, duration: 0.015 * t)
                    CubicKeyframe(0, duration: 0.135 * t)
                    LinearKeyframe(0, duration: 0.27 * t)
                }
                KeyframeTrack(\.blueOpacity) {
                    LinearKeyframe(0.85, duration: 0.02 * t)
                    LinearKeyframe(0.75, duration: 0.20 * t)
                    CubicKeyframe(0, duration: 0.20 * t)
                }
                // Passe rose : part après un léger décalage et se cale à 1,5 pt vers 280 ms.
                KeyframeTrack(\.pinkShift) {
                    LinearKeyframe(1, duration: 0.06 * t)
                    CubicKeyframe(0, duration: 0.22 * t)
                    LinearKeyframe(0, duration: 0.14 * t)
                }
                KeyframeTrack(\.pinkOpacity) {
                    LinearKeyframe(0, duration: 0.05 * t)
                    LinearKeyframe(0.88, duration: 0.04 * t)
                    LinearKeyframe(0.78, duration: 0.19 * t)
                    CubicKeyframe(0, duration: 0.14 * t)
                }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Matière papier & trame demi-teinte (en cache)

/// Textures risographiques calculées une seule fois en bitmap Retina :
/// grain de papier recyclé (~4 %) avec fibres et mouchetures, et trame de points demi-teinte à 45°.
private enum RisoTextures {
    static let paperLight: NSImage = makeRecycledPaper(dark: false)
    static let paperDark: NSImage = makeRecycledPaper(dark: true)
    static let halftone: NSImage = makeHalftoneScreen()

    static func paper(dark: Bool) -> NSImage { dark ? paperDark : paperLight }

    private static func hash(_ x: Int, _ y: Int, _ seed: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263 &+ seed &* 1_442_695_041)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFF) / 65_535.0
    }

    /// Grain de papier recyclé ~4 % + fibres végétales + fines mouchetures kraft/ardoise, raccord parfait.
    private static func makeRecycledPaper(dark: Bool) -> NSImage {
        let side = 160, scale = 2
        let px = side * scale
        guard let ctx = bitmapContext(width: px, height: px),
              let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else {
            return NSImage(size: NSSize(width: side, height: side))
        }

        // Grain organique ~10 % (micro-alvéoles du papier recyclé non couché).
        for y in 0..<px {
            for x in 0..<px {
                // Cellules d'un et deux points : un grain que l'œil lit vraiment comme du papier.
                let n1 = hash(x / 2, y / 2, dark ? 101 : 17)
                let n2 = hash(x / 4, y / 4, dark ? 137 : 43)
                let combined = n1 * 0.66 + n2 * 0.34
                let centered = (combined - 0.5) * 2.0
                let strength = abs(centered) * (dark ? 0.075 : 0.08) * (centered > 0 ? 0.7 : 1)
                let idx = (y * px + x) * 4
                let a = UInt8(min(max(strength * 255.0, 0), 255))
                if dark {
                    // Papier anthracite : grain ardoise bleuté / craie très doux (jamais noir pur).
                    let isLight = centered > 0
                    let r: Double = isLight ? 0.80 : 0.06
                    let g: Double = isLight ? 0.82 : 0.07
                    let b: Double = isLight ? 0.92 : 0.15
                    data[idx] = UInt8(r * Double(a))
                    data[idx + 1] = UInt8(g * Double(a))
                    data[idx + 2] = UInt8(b * Double(a))
                    data[idx + 3] = a
                } else {
                    // Papier brut : grain chaud ocre/écru (aucun noir pur).
                    let isLight = centered > 0
                    let r: Double = isLight ? 1.0 : 0.36
                    let g: Double = isLight ? 0.98 : 0.31
                    let b: Double = isLight ? 0.92 : 0.24
                    data[idx] = UInt8(r * Double(a))
                    data[idx + 1] = UInt8(g * Double(a))
                    data[idx + 2] = UInt8(b * Double(a))
                    data[idx + 3] = a
                }
            }
        }

        // Fibres de papier recyclé (courtes fibres d'orientation variée).
        ctx.setLineCap(.round)
        let fiberCount = dark ? 48 : 62
        for i in 0..<fiberCount {
            let x0 = hash(i, 1, dark ? 311 : 211) * Double(px)
            let y0 = hash(i, 2, dark ? 311 : 211) * Double(px)
            let angle = hash(i, 3, dark ? 311 : 211) * .pi * 2
            let len = 4.5 + hash(i, 4, dark ? 311 : 211) * 10.5
            let width = 0.65 + hash(i, 5, dark ? 311 : 211) * 0.55
            let warm = hash(i, 6, dark ? 311 : 211) > 0.38
            ctx.setLineWidth(width)
            if dark {
                ctx.setStrokeColor(CGColor(srgbRed: warm ? 0.66 : 0.34, green: warm ? 0.69 : 0.58,
                                           blue: warm ? 0.82 : 0.76, alpha: warm ? 0.095 : 0.07))
            } else {
                ctx.setStrokeColor(CGColor(srgbRed: warm ? 0.50 : 0.25, green: warm ? 0.42 : 0.32,
                                           blue: warm ? 0.30 : 0.50, alpha: warm ? 0.13 : 0.09))
            }
            let x1 = x0 + cos(angle) * len
            let y1 = y0 + sin(angle) * len
            for ox in [-Double(px), 0, Double(px)] {
                for oy in [-Double(px), 0, Double(px)] {
                    let sx = x0 + ox, sy = y0 + oy, ex = x1 + ox, ey = y1 + oy
                    if max(sx, ex) >= 0 && min(sx, ex) <= Double(px) && max(sy, ey) >= 0 && min(sy, ey) <= Double(px) {
                        ctx.move(to: CGPoint(x: sx, y: sy))
                        ctx.addLine(to: CGPoint(x: ex, y: ey))
                        ctx.strokePath()
                    }
                }
            }
        }

        // Petites mouchetures recyclées (inclusions de pâte à papier).
        let fleckCount = dark ? 28 : 38
        for i in 0..<fleckCount {
            let fx = hash(i, 11, dark ? 509 : 401) * Double(px)
            let fy = hash(i, 12, dark ? 509 : 401) * Double(px)
            let r = 0.8 + hash(i, 13, dark ? 509 : 401) * 1.15
            if dark {
                ctx.setFillColor(CGColor(srgbRed: 0.76, green: 0.78, blue: 0.88, alpha: 0.105))
            } else {
                ctx.setFillColor(CGColor(srgbRed: 0.44, green: 0.36, blue: 0.25, alpha: 0.16))
            }
            ctx.fillEllipse(in: CGRect(x: fx - r, y: fy - r, width: r * 2, height: r * 2))
        }

        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: side, height: side)) }
        return NSImage(cgImage: cg, size: NSSize(width: side, height: side))
    }

    /// Trame de points demi-teinte à 45° (tuile 6 × 6 pt @2x, blanche pour être teintée via `colorMultiply`).
    private static func makeHalftoneScreen() -> NSImage {
        let side = 6, scale = 2
        let px = side * scale
        guard let ctx = bitmapContext(width: px, height: px) else {
            return NSImage(size: NSSize(width: side, height: side))
        }
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        let r: CGFloat = 1.65
        let centers: [(CGFloat, CGFloat)] = [
            (CGFloat(px) * 0.25, CGFloat(px) * 0.25),
            (CGFloat(px) * 0.75, CGFloat(px) * 0.75),
        ]
        for (cx, cy) in centers {
            ctx.fillEllipse(in: CGRect(x: cx - r, y: cy - r, width: r * 2, height: r * 2))
        }
        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: side, height: side)) }
        return NSImage(cgImage: cg, size: NSSize(width: side, height: side))
    }

    private static func bitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}

// MARK: - Vues de décor Riso

/// Fond du cadre (papier recyclé texturé, léger lavis d'encre d'atelier).
struct RisoSurface: View {
    let decor: RisoDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            Rectangle()
                .fill(ImagePaint(image: Image(nsImage: RisoTextures.paper(dark: decor.dark))))
                .opacity(decor.grain ? 1 : 0)
            LinearGradient(
                colors: [
                    decor.blue.opacity(decor.dark ? 0.04 : 0.025),
                    .clear,
                    decor.accent.opacity(decor.dark ? 0.035 : 0.02),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

/// Fond du panneau intérieur (feuille de papier recyclé texturée, lisible et mate).
struct RisoPane: View {
    let decor: RisoDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Rectangle()
            .fill(ImagePaint(image: Image(nsImage: RisoTextures.paper(dark: decor.dark))))
                .opacity(decor.grain ? 1 : 0)
            .clipShape(shape)
            .allowsHitTesting(false)
    }
}

/// Sélection par décalage de repérage :
/// un aplat rose translucide (avec trame demi-teinte optionnelle) décalé de 2 × 1,5 pt
/// par rapport à un contour bleu net en (0, 0). Le texte n'est jamais décalé.
struct RisoSelection: View {
    let decor: RisoDecor
    let radius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let tiny = geo.size.height < 22
            let dx: CGFloat = tiny ? 1.1 : 2.0
            let dy: CGFloat = tiny ? 0.85 : 1.5
            let lineWidth: CGFloat = tiny ? 1.0 : 1.5
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            let blend: BlendMode = decor.dark ? .screen : .multiply

            ZStack {
                // Passe rose fluo décalée de (2 ; 1,5) pt : aplat translucide + trame demi-teinte optionnelle.
                ZStack {
                    shape
                        .fill(decor.accent.opacity(decor.dark ? 0.32 : 0.23))
                    if decor.halftone && !tiny {
                        Rectangle()
                            .fill(ImagePaint(image: Image(nsImage: RisoTextures.halftone)))
                            .colorMultiply(decor.accent)
                            .opacity(decor.dark ? 0.30 : 0.24)
                            .clipShape(shape)
                    }
                }
                .offset(x: dx, y: dy)
                .blendMode(blend)

                // Passe bleue nette en (0, 0) : encadre le texte sans jamais le déplacer.
                // Là où elle recouvre la passe rose, la surimpression (multiply / screen) crée le violet.
                shape
                    .strokeBorder(decor.blue.opacity(decor.dark ? 0.94 : 0.96), lineWidth: lineWidth)
                    .blendMode(blend)
            }
            .compositingGroup()
        }
        .allowsHitTesting(false)
    }
}

/// Séparateur risographique : discrets repères de repérage (croix d'imprimerie bicolores dans les marges)
/// sous l'en-tête et au-dessus du pied de page, sans doublonner la bordure du panneau intérieur.
struct RisoDivider: View {
    let decor: RisoDecor
    let vertical: Bool
    let role: StyleDivider.Role

    var body: some View {
        if vertical {
            Rectangle()
                .fill(decor.blue.opacity(decor.dark ? 0.26 : 0.24))
                .allowsHitTesting(false)
        } else if role != .plain {
            let blend: BlendMode = decor.dark ? .screen : .multiply
            let yShift: CGFloat = role == .header ? -3.5 : 3.5
            Color.clear
                .overlay {
                    HStack(spacing: 0) {
                        registrationTick(blend: blend)
                        Spacer(minLength: 0)
                        // Fine trace rose pointillée dans la marge du cadre, comme un filet de repérage.
                        HRule()
                            .stroke(decor.accent.opacity(decor.dark ? 0.30 : 0.34),
                                    style: StrokeStyle(lineWidth: 0.75, dash: [2, 5]))
                            .frame(height: 1)
                            .padding(.horizontal, 10)
                            .blendMode(blend)
                        Spacer(minLength: 0)
                        registrationTick(blend: blend)
                    }
                    .padding(.horizontal, 10)
                    .offset(y: yShift)
                }
                .allowsHitTesting(false)
        }
    }

    private func registrationTick(blend: BlendMode) -> some View {
        ZStack {
            // Croix rose légèrement décalée.
            crosshair(color: decor.accent.opacity(decor.dark ? 0.50 : 0.60))
                .offset(x: 0.8, y: 0.6)
                .blendMode(blend)
            // Croix bleue nette.
            crosshair(color: decor.blue.opacity(decor.dark ? 0.56 : 0.68))
                .blendMode(blend)
        }
        .compositingGroup()
    }

    private func crosshair(color: Color) -> some View {
        ZStack {
            Rectangle().fill(color).frame(width: 5, height: 0.75)
            Rectangle().fill(color).frame(width: 0.75, height: 5)
        }
        .frame(width: 5, height: 5)
    }
}

/// Pastille d'un symbole : bichromie dans l'encre bleue au repos, avec un fantôme rose fluo
/// décalé d'1 pt une fois choisie (surimpression violette au croisement).
struct RisoTile: View {
    let decor: RisoDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        let blend: BlendMode = decor.dark ? .screen : .multiply
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let corner = max(3, side * 0.22)
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
            let glyphSize = max(8, side * 0.48)
            let ghostShift: CGFloat = side < 16 ? 0.7 : 1.0

            ZStack {
                // Fond de pastille : papier teinté d'encre au repos, légère surimpression rose quand choisie.
                shape
                    .fill(decor.blue.opacity(decor.dark ? (selected ? 0.18 : 0.12) : (selected ? 0.08 : 0.06)))
                if selected {
                    shape
                        .fill(decor.accent.opacity(decor.dark ? 0.24 : 0.20))
                        .offset(x: ghostShift, y: ghostShift)
                        .blendMode(blend)
                }
                shape
                    .strokeBorder(decor.blue.opacity(decor.dark ? (selected ? 0.88 : 0.45) : (selected ? 0.85 : 0.36)),
                                  lineWidth: side < 16 ? 0.75 : 1.1)

                // Symbole en bichromie : fantôme rose décalé d'1 pt une fois choisi + passe bleue nette.
                ZStack {
                    if selected {
                        Image(systemName: name)
                            .font(.system(size: glyphSize, weight: .semibold))
                            .foregroundStyle(decor.accent.opacity(decor.dark ? 0.95 : 0.92))
                            .offset(x: ghostShift, y: ghostShift)
                            .blendMode(blend)
                    }
                    Image(systemName: name)
                        .font(.system(size: glyphSize, weight: .semibold))
                        .foregroundStyle(decor.blue)
                        .blendMode(blend)
                }
                .compositingGroup()
            }
            .padding(1)
        }
    }
}

/// Anneau du logo : passe bleue légèrement décalée vers le haut-gauche (mauvais repérage d'imprimerie).
struct RisoMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        let dark = RisoLook.isDark
        let blend: BlendMode = dark ? .screen : .multiply
        let shift = max(0.35, line * 0.22)
        ZStack {
            // Discret écho rose décalé pour évoquer le double passage du tambour.
            MarkRing().trim(from: 0, to: progress)
                .stroke(dot.opacity(dark ? 0.28 : 0.22), style: StrokeStyle(lineWidth: line * 0.90, lineCap: .round))
                .offset(x: shift * 1.35, y: shift * 1.05)
                .blendMode(blend)
            // Anneau principal en encre bleue nette.
            MarkRing().trim(from: 0, to: progress)
                .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
                .offset(x: -shift * 0.45, y: -shift * 0.35)
                .blendMode(blend)
        }
        .compositingGroup()
    }
}

/// Point du logo : encre rose fluo pure, décalée par rapport au repère de l'anneau bleu (mauvais repérage).
struct RisoMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        let shift = max(0.55, line * 0.40)
        Circle()
            .fill(dot)
            .frame(width: 2 * radius, height: 2 * radius)
            .offset(x: shift, y: shift * 0.85)
    }
}

/// Réglages › Apparence, quand la peau Riso est choisie.
struct RisoSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Variante", selection: $settings.risoMode) {
                ForEach(RisoMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Trame demi-teinte", isOn: $settings.risoHalftone)
            Toggle("Icônes en bichromie", isOn: $settings.risoDuotoneIcons)
            Toggle("Grain du papier recyclé", isOn: $settings.risoGrain)
        } header: {
            Text("Riso")
        } footer: {
            Text("Impression risographique en deux encres (bleu et rose fluo) sur papier recyclé, avec décalage de repérage.")
        }
    }
}
