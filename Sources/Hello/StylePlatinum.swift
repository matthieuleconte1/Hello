import AppKit
import SwiftUI

// Atelier Platinum : l'apparence Apple Platinum de Mac OS 8 et 9 (Macintosh Human Interface Guidelines classiques).
// Gris perle structuré par des biseaux au pixel près (lumière en haut à gauche, ombre en bas à droite),
// en-tête à fines rayures horizontales (pinstripes en motif bitmap mis en cache), puits de liste à biseau inversé,
// sélection pleine largeur sans arrondi façon Finder, touches et pastilles en boutons biseautés, Geneva,
// et ouverture en « Zoom Rects ».
//
// Ce fichier contient tout ce qui est propre au style. Les composants partagés l'appellent par ces points d'entrée :
// `PlatinumLook` (jetons, mouvement, réglages), `PlatinumDecor` et les vues `Platinum…` (décor), `PlatinumSettings`.

/// Variante de la peau (« Auto » suit l'apparence du Mac).
enum PlatinumMode: String, CaseIterable, Identifiable {
    case auto, platinum, graphite
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .platinum: "Platinum"
        case .graphite: "Graphite"
        }
    }
}

/// Couleur de surlignage (Tableau de bord Apparence de Mac OS 8) : bleu, lavande, menthe ou or.
enum PlatinumHighlight: String, CaseIterable, Identifiable {
    case blue, lavender, mint, gold
    var id: String { rawValue }
    var title: String {
        switch self {
        case .blue: "Bleu"
        case .lavender: "Lavande"
        case .mint: "Menthe"
        case .gold: "Or"
        }
    }

    struct Colors {
        let selection: Color
        let selectionInk: Color
        let accent: Color
        let primaryKeyInk: Color
        let depressedFill: Color
    }

    func colors(dark: Bool) -> Colors {
        switch self {
        case .blue:
            dark
                ? Colors(selection: Color(hex: "#4C5D9E"), selectionInk: .white,
                         accent: Color(hex: "#7A8EE0"), primaryKeyInk: .white,
                         depressedFill: Color(hex: "#394880"))
                : Colors(selection: Color(hex: "#333399"), selectionInk: .white,
                         accent: Color(hex: "#333399"), primaryKeyInk: .white,
                         depressedFill: Color(hex: "#26267A"))
        case .lavender:
            dark
                ? Colors(selection: Color(hex: "#6A5599"), selectionInk: .white,
                         accent: Color(hex: "#A58CE6"), primaryKeyInk: .white,
                         depressedFill: Color(hex: "#52407A"))
                : Colors(selection: Color(hex: "#6B4C9A"), selectionInk: .white,
                         accent: Color(hex: "#6B4C9A"), primaryKeyInk: .white,
                         depressedFill: Color(hex: "#52387A"))
        case .mint:
            dark
                ? Colors(selection: Color(hex: "#2D705F"), selectionInk: .white,
                         accent: Color(hex: "#5CC4A8"), primaryKeyInk: Color(hex: "#101614"),
                         depressedFill: Color(hex: "#205447"))
                : Colors(selection: Color(hex: "#246E5A"), selectionInk: .white,
                         accent: Color(hex: "#246E5A"), primaryKeyInk: .white,
                         depressedFill: Color(hex: "#195242"))
        case .gold:
            dark
                ? Colors(selection: Color(hex: "#B88B22"), selectionInk: Color(hex: "#141000"),
                         accent: Color(hex: "#E0B84C"), primaryKeyInk: Color(hex: "#141000"),
                         depressedFill: Color(hex: "#8F6A16"))
                : Colors(selection: Color(hex: "#D6A836"), selectionInk: Color(hex: "#141000"),
                         accent: Color(hex: "#9A6E00"), primaryKeyInk: .white,
                         depressedFill: Color(hex: "#B5891E"))
        }
    }

    /// Pastille de couleur affichée dans Réglages › Apparence.
    var swatch: Color {
        switch self {
        case .blue: Color(hex: "#333399")
        case .lavender: Color(hex: "#6B4C9A")
        case .mint: Color(hex: "#246E5A")
        case .gold: Color(hex: "#D6A836")
        }
    }
}

/// Palette complète Platinum (Mac OS 8/9) et Graphite (sombre).
private enum PlatinumPalette {
    // Platinum (clair)
    static let lightFrame = Color(hex: "#DDDDDD")
    static let lightPane = Color(hex: "#FFFFFF")
    static let lightInk = Color(hex: "#000000")
    static let lightBevelLight = Color(hex: "#FFFFFF")
    static let lightBevelMidLight = Color(hex: "#EEEEEE")
    static let lightBevelMidDark = Color(hex: "#BBBBBB")
    static let lightBevelDark = Color(hex: "#888888")
    static let lightBorder = Color(hex: "#000000")
    static let lightWellBorder = Color(hex: "#555555")
    static let lightKeyFill = Color(hex: "#EAEAEA")
    static let lightKeyBorder = Color(hex: "#555555")
    static let lightButtonTop = Color(hex: "#F2F2F2")
    static let lightButtonBottom = Color(hex: "#D2D2D2")

    // Graphite (sombre)
    static let darkFrame = Color(hex: "#3A3D44")
    static let darkPane = Color(hex: "#24262B")
    static let darkInk = Color(hex: "#ECEEF2")
    static let darkBevelLight = Color(hex: "#525660")
    static let darkBevelMidLight = Color(hex: "#454952")
    static let darkBevelMidDark = Color(hex: "#2A2C32")
    static let darkBevelDark = Color(hex: "#141518")
    static let darkBorder = Color(hex: "#0C0D0F")
    static let darkWellBorder = Color(hex: "#141518")
    static let darkKeyFill = Color(hex: "#464A53")
    static let darkKeyBorder = Color(hex: "#141518")
    static let darkButtonTop = Color(hex: "#4D515B")
    static let darkButtonBottom = Color(hex: "#343740")
}

/// Ce que le décor de la peau a besoin de savoir pour se dessiner.
struct PlatinumDecor {
    var dark: Bool
    var ink: Color
    var accent: Color
    var selection: Color
    var selectionInk: Color
    var depressedFill: Color
    var bevelLight: Color
    var bevelMidLight: Color
    var bevelMidDark: Color
    var bevelDark: Color
    var pinstripes: Bool
}

enum PlatinumLook {
    static let detail = "Apple Platinum de Mac OS 8 et 9 : gris ciselé, biseaux d'un pixel, Geneva."
    static let symbol = "macwindow"
    static let summary = "instantané et net : trois cadres filaires « Zoom Rects » grandissent en 140 ms puis la fenêtre "
        + "apparaît d'un coup ; au lancement d'une app, bref clignotement façon menu Mac OS."
    static let effect = "trois cadres filaires « Zoom Rects » grandissent du centre vers le panneau."

    /// Variante sombre active.
    static var isDark: Bool {
        let mode = AppSettings.shared.platinumMode
        if mode == .auto { return StyleTokens.systemIsDark }
        return mode == .graphite
    }

    /// Ce qui change l'aspect du champ de recherche.
    static var signature: String {
        let s = AppSettings.shared
        return [s.platinumMode.rawValue, s.platinumHighlight.rawValue, "\(s.platinumPinstripes)"].joined(separator: "|")
    }

    /// « Réinitialiser l'apparence » : remet les réglages de la peau par défaut.
    static func resetSettings(_ s: AppSettings) {
        s.platinumMode = .auto
        s.platinumHighlight = .blue
        s.platinumPinstripes = true
    }

    static var tokens: StyleTokens {
        let p = PlatinumPalette.self
        let s = AppSettings.shared
        let dark = isDark
        let hi = s.platinumHighlight.colors(dark: dark)
        let frame = dark ? p.darkFrame : p.lightFrame
        let pane = dark ? p.darkPane : p.lightPane
        let ink = dark ? p.darkInk : p.lightInk
        let bevelLight = dark ? p.darkBevelLight : p.lightBevelLight
        let bevelMidLight = dark ? p.darkBevelMidLight : p.lightBevelMidLight
        let bevelMidDark = dark ? p.darkBevelMidDark : p.lightBevelMidDark
        let bevelDark = dark ? p.darkBevelDark : p.lightBevelDark

        return StyleTokens(
            surface: .inset(frame: frame, pane: pane),
            dark: dark, ink: ink, chromeInk: ink, chromeDark: dark,
            accent: hi.accent, accent2: bevelDark, live: hi.accent, toast: hi.accent,
            selectionFill: hi.selection,
            selectionInk: hi.selectionInk,
            rowRadius: 3, cellRadius: 4,
            radius: 9,
            border: (dark ? p.darkBorder : p.lightBorder, 1),
            hardShadow: 2,
            hardShadowColor: Color.black.opacity(dark ? 0.85 : 0.65),
            divider: .clear,
            titleWeight: .regular,
            searchWeight: .semibold,
            header: .plain,
            markSkin: .platinum(ink: ink, dot: hi.accent),
            fontFamily: "Geneva",
            displayFamily: "SF Compact",
            paneBorder: nil,
            paneRadius: 4,
            iconButton: dark ? (Color(hex: "#4C505B"), p.darkInk) : (Color(hex: "#CCCCCC"), p.lightInk),
            strongMeta: true,
            keyFill: dark ? p.darkKeyFill : p.lightKeyFill,
            keyInk: ink.opacity(dark ? 0.92 : 0.90),
            keyBorder: dark ? p.darkKeyBorder : p.lightKeyBorder,
            primaryKeyFill: hi.selection,
            primaryKeyInk: hi.selectionInk,
            keyRaised: true,
            launchTint: hi.selection,
            tile: .decor,
            iconSaturation: 1.0,
            motion: nil,
            decor: .platinum(PlatinumDecor(
                dark: dark,
                ink: ink,
                accent: hi.accent,
                selection: hi.selection,
                selectionInk: hi.selectionInk,
                depressedFill: hi.depressedFill,
                bevelLight: bevelLight,
                bevelMidLight: bevelMidLight,
                bevelMidDark: bevelMidDark,
                bevelDark: bevelDark,
                pinstripes: s.platinumPinstripes
            ))
        )
    }

    /// Fond derrière la vignette : bureau bleu-gris classique Mac OS 8/9 ou ardoise Graphite.
    @ViewBuilder static var backdrop: some View {
        if isDark {
            LinearGradient(colors: [Color(hex: "#444A58"), Color(hex: "#2B2F3A")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            LinearGradient(colors: [Color(hex: "#6B82A8"), Color(hex: "#4C6185")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Mouvement

    /// Apparition nette dès la fin des Zoom Rects.
    static func open(light: Bool) -> Animation {
        light ? .linear(duration: 0.04) : .linear(duration: 0.05)
    }

    static let navigation = Animation.linear(duration: 0.08)
    static func modeTransition(forward: Bool) -> AnyTransition { .opacity }

    /// Une fois la fenêtre posée, les lignes se dessinent de haut en bas comme une liste QuickDraw, sans fondu.
    static func row(_ order: Int) -> Animation {
        .linear(duration: 0.001).delay(0.21 + Double(min(order, 12)) * 0.022)
    }

    static let close = Animation.linear(duration: 0.16)
    static let rowOffset: CGSize = .zero
    static let rowScale: CGFloat = 1
}

/// Le panneau entier, à la Mac OS 8/9 : d'abord les « Zoom Rects » (quatre cadres filaires qui grandissent du
/// centre vers la fenêtre), et la fenêtre n'apparaît d'un coup qu'une fois le dernier cadre arrivé. Au lancement
/// d'une app : le double clignotement d'un article de menu choisi.
struct PlatinumPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        let t = 1 / Motion.speed
        let dip = max(0.35, 1 - 0.55 * Double(min(Motion.amplitude, 1.2)))
        let zoom = Motion.enabled && !light
        content
            .keyframeAnimator(initialValue: 1.0, trigger: closing) { view, flash in
                view.opacity(closing && Motion.enabled ? flash : 1)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(dip, duration: 0.035 * t)
                    LinearKeyframe(1.0, duration: 0.035 * t)
                    LinearKeyframe(dip, duration: 0.035 * t)
                    LinearKeyframe(1.0, duration: 0.045 * t)
                }
            }
            .keyframeAnimator(initialValue: 1.0, trigger: revealID) { view, progress in
                // La fenêtre reste invisible pendant les cadres, puis s'affiche d'un bloc (aucun fondu).
                view.opacity(!zoom || progress >= 0.999 ? 1 : 0)
                    .overlay {
                        if zoom && progress < 0.999 {
                            ZoomRects(progress: progress, dark: StyleTokens.current.dark)
                        }
                    }
            } keyframes: { _ in
                LinearKeyframe(0, duration: 0.001)
                LinearKeyframe(1, duration: 0.2 * t)
            }
            .opacity(hidden ? 0 : 1)
    }
}

/// Quatre cadres filaires échelonnés qui grandissent du centre jusqu'au bord de la fenêtre, en paliers
/// francs comme le Finder classique (pas d'anticrénelage flou, traits d'un point avec liseré contrasté).
private struct ZoomRects: View {
    let progress: Double
    let dark: Bool

    var body: some View {
        let amp = Double(min(max(Motion.amplitude, 0.5), 1.4))
        let startScale = max(0.06, 0.4 - 0.3 * amp)
        Canvas { ctx, size in
            let cx = size.width / 2, cy = size.height / 2
            for index in 0..<4 {
                let delay = Double(index) * 0.12
                let local = min(max((progress - delay) / (1 - 0.36), 0), 1)
                guard local > 0 else { continue }
                // Paliers : six positions par cadre, comme un tracé XOR redessiné à chaque tic.
                let stepped = (local * 6).rounded(.down) / 6
                let eased = 1 - pow(1 - max(stepped, 0.08), 1.4)
                let scale = startScale + (1 - startScale) * eased
                let w = max(6, size.width * scale), h = max(6, size.height * scale)
                let rect = CGRect(x: (cx - w / 2).rounded() + 0.5, y: (cy - h / 2).rounded() + 0.5,
                                  width: max(2, w.rounded() - 1), height: max(2, h.rounded() - 1))
                let halo = dark ? Color.black.opacity(0.7) : Color.white.opacity(0.9)
                let wire = dark ? Color.white.opacity(0.95) : Color.black.opacity(0.9)
                ctx.stroke(Path(rect.insetBy(dx: -1, dy: -1)), with: .color(halo), lineWidth: 1)
                ctx.stroke(Path(rect), with: .color(wire), lineWidth: 1)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Les Zoom Rects sont joués par `PlatinumPanelMotion` (ils doivent précéder la fenêtre) : rien à dessiner ici.
struct PlatinumOpening: View {
    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        Color.clear.frame(width: size.width, height: size.height).allowsHitTesting(false)
    }
}

// MARK: - Motifs bitmap mis en cache (pinstripes)

/// Motifs Platinum calculés une seule fois en bitmap Retina (aucun calcul par image).
private enum PlatinumTextures {
    static let pinstripesLight = makePinstripes(dark: false)
    static let pinstripesDark = makePinstripes(dark: true)

    static func pinstripes(dark: Bool) -> NSImage { dark ? pinstripesDark : pinstripesLight }

    /// Rayures horizontales fines de Mac OS 8/9 : pas de 2 pt (1 pt clair + 1 pt ombré), subtiles pour garder
    /// une lisibilité parfaite du texte de recherche par-dessus.
    private static func makePinstripes(dark: Bool) -> NSImage {
        let width = 4, height = 2, scale = 2
        let pxW = width * scale, pxH = height * scale
        guard let ctx = CGContext(data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        // Ligne haute (lumière) : 1 pt = 2 px en @2x.
        if dark {
            ctx.setFillColor(CGColor(srgbRed: 0.35, green: 0.37, blue: 0.42, alpha: 0.48))
        } else {
            ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.56))
        }
        ctx.fill(CGRect(x: 0, y: scale, width: pxW, height: scale))

        // Ligne basse (ombre douce) : 1 pt = 2 px en @2x.
        if dark {
            ctx.setFillColor(CGColor(srgbRed: 0.10, green: 0.11, blue: 0.14, alpha: 0.48))
        } else {
            ctx.setFillColor(CGColor(srgbRed: 0.58, green: 0.58, blue: 0.60, alpha: 0.28))
        }
        ctx.fill(CGRect(x: 0, y: 0, width: pxW, height: scale))

        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: width, height: height)) }
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
}

// MARK: - Décor Platinum (cadre, puits, sélection, séparateurs, pastilles, logo)

/// Fond du cadre Platinum : biseau d'un pixel au cordeau (lumière haut-gauche, ombre bas-droite) à l'intérieur
/// de la bordure noire, plus fines rayures horizontales (pinstripes) dans la bande d'en-tête.
struct PlatinumSurface: View {
    let decor: PlatinumDecor
    let radius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let full = h >= 260
            let headerH: CGFloat = full ? 60 : h * (40.0 / 190.0)
            let stripePadH: CGFloat = full ? 7 : max(2, 4 * (h / 190.0))
            let stripePadV: CGFloat = full ? 9 : max(2, 5 * (h / 190.0))

            ZStack(alignment: .topLeading) {
                // Rayures horizontales (pinstripes) dans l'en-tête, façon barre de titre Mac OS 8/9.
                if decor.pinstripes && headerH >= 14 {
                    let stripeW = max(0, w - 2 * stripePadH)
                    let stripeH = max(0, headerH - 2 * stripePadV)
                    Rectangle()
                        .fill(ImagePaint(image: Image(nsImage: PlatinumTextures.pinstripes(dark: decor.dark))))
                        .frame(width: stripeW, height: stripeH)
                        .offset(x: stripePadH, y: stripePadV)
                }

                // Double biseau intérieur au pixel près (juste à l'intérieur de la bordure noire de 1 pt), qui suit
                // l'arrondi du cadre : un biseau à angles vifs dépasserait dans les coins.
                Canvas { ctx, size in
                    let bounds = CGRect(origin: .zero, size: size)
                    drawRoundedBevel(in: &ctx, rect: bounds.insetBy(dx: 1.5, dy: 1.5), radius: max(0, radius - 1.5),
                                     topLeft: decor.bevelLight, bottomRight: decor.bevelDark)
                    if min(size.width, size.height) > 100 {
                        drawRoundedBevel(in: &ctx, rect: bounds.insetBy(dx: 2.5, dy: 2.5), radius: max(0, radius - 2.5),
                                         topLeft: decor.bevelMidLight, bottomRight: decor.bevelMidDark)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .allowsHitTesting(false)
    }
}

/// Trace un biseau d'un point net autour d'un rectangle : lumière en haut et à gauche, ombre en bas et à droite,
/// avec raccords d'angle en demi-teinte comme les fenêtres Platinum de Mac OS 8 et 9.
private func drawBevel(in ctx: inout GraphicsContext, rect: CGRect, topLeft: Color, bottomRight: Color, corner: Color) {
    guard rect.width >= 4, rect.height >= 4 else { return }
    let x0 = rect.minX + 0.5, x1 = rect.maxX - 0.5
    let y0 = rect.minY + 0.5, y1 = rect.maxY - 0.5

    var tl = Path()
    tl.move(to: CGPoint(x: x0, y: y1 - 0.5))
    tl.addLine(to: CGPoint(x: x0, y: y0))
    tl.addLine(to: CGPoint(x: x1 - 0.5, y: y0))
    ctx.stroke(tl, with: .color(topLeft), lineWidth: 1)

    var br = Path()
    br.move(to: CGPoint(x: x1, y: y0 + 0.5))
    br.addLine(to: CGPoint(x: x1, y: y1))
    br.addLine(to: CGPoint(x: x0 + 0.5, y: y1))
    ctx.stroke(br, with: .color(bottomRight), lineWidth: 1)

    // Pixels d'onglet aux deux coins neutres (haut-droit et bas-gauche).
    ctx.fill(Path(CGRect(x: rect.maxX - 1, y: rect.minY, width: 1, height: 1)), with: .color(corner))
    ctx.fill(Path(CGRect(x: rect.minX, y: rect.maxY - 1, width: 1, height: 1)), with: .color(corner))
}

/// Puits biseauté inversé autour de la liste : ombre en haut à gauche, lumière en bas à droite,
/// tracé exactement sur les deux moitiés du contour arrondi (aucune rupture de dégradé sur les bords longs).
struct PlatinumPane: View {
    let decor: PlatinumDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            // Légère ombre portée sous le rebord supérieur du puits.
            VStack(spacing: 0) {
                LinearGradient(colors: [Color.black.opacity(decor.dark ? 0.34 : 0.09), .clear],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 3)
                Spacer(minLength: 0)
            }

            // Double marche biseautée inversée, tracée au pixel près sur les bords haut-gauche et bas-droite.
            Canvas { ctx, size in
                let outer = CGRect(origin: .zero, size: size).insetBy(dx: 0.5, dy: 0.5)
                drawRoundedBevel(
                    in: &ctx, rect: outer, radius: max(0, radius - 0.5),
                    topLeft: decor.dark ? Color(hex: "#0D0E10") : Color(hex: "#777777"),
                    bottomRight: decor.dark ? Color(hex: "#585D68") : Color(hex: "#FFFFFF")
                )
                if min(size.width, size.height) > 30 {
                    let inner = CGRect(origin: .zero, size: size).insetBy(dx: 1.5, dy: 1.5)
                    drawRoundedBevel(
                        in: &ctx, rect: inner, radius: max(0, radius - 1.5),
                        topLeft: decor.dark ? Color(hex: "#141518") : Color(hex: "#444444"),
                        bottomRight: decor.dark ? Color(hex: "#383C44") : Color(hex: "#CCCCCC")
                    )
                }
            }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

/// Trace un biseau d'1 pt sur un rectangle arrondi : tout le côté gauche + tout le bord supérieur dans `topLeft`,
/// tout le côté droit + tout le bord inférieur dans `bottomRight`, avec onglet net à 45° aux coins neutres.
private func drawRoundedBevel(in ctx: inout GraphicsContext, rect: CGRect, radius: CGFloat,
                              topLeft: Color, bottomRight: Color) {
    guard rect.width >= 4, rect.height >= 4 else { return }
    let r = min(radius, min(rect.width, rect.height) / 2)
    let x0 = rect.minX, x1 = rect.maxX
    let y0 = rect.minY, y1 = rect.maxY

    // Moitié haut-gauche : de 135° au coin bas-gauche → bord gauche → coin haut-gauche → bord haut → 315° au coin haut-droit.
    var tl = Path()
    tl.addArc(center: CGPoint(x: x0 + r, y: y1 - r), radius: r,
              startAngle: .degrees(135), endAngle: .degrees(180), clockwise: false)
    tl.addLine(to: CGPoint(x: x0, y: y0 + r))
    tl.addArc(center: CGPoint(x: x0 + r, y: y0 + r), radius: r,
              startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
    tl.addLine(to: CGPoint(x: x1 - r, y: y0))
    tl.addArc(center: CGPoint(x: x1 - r, y: y0 + r), radius: r,
              startAngle: .degrees(270), endAngle: .degrees(315), clockwise: false)
    ctx.stroke(tl, with: .color(topLeft), style: StrokeStyle(lineWidth: 1, lineCap: .square))

    // Moitié bas-droite : de 315° au coin haut-droit → bord droit → coin bas-droit → bord bas → 135° au coin bas-gauche.
    var br = Path()
    br.addArc(center: CGPoint(x: x1 - r, y: y0 + r), radius: r,
              startAngle: .degrees(315), endAngle: .degrees(360), clockwise: false)
    br.addLine(to: CGPoint(x: x1, y: y1 - r))
    br.addArc(center: CGPoint(x: x1 - r, y: y1 - r), radius: r,
              startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
    br.addLine(to: CGPoint(x: x0 + r, y: y1))
    br.addArc(center: CGPoint(x: x0 + r, y: y1 - r), radius: r,
              startAngle: .degrees(90), endAngle: .degrees(135), clockwise: false)
    ctx.stroke(br, with: .color(bottomRight), style: StrokeStyle(lineWidth: 1, lineCap: .square))
}

/// Surlignage Finder Mac OS 9 : aplat pleine largeur sans arrondi, bordé d'un filet haut/bas net.
struct PlatinumSelection: View {
    let decor: PlatinumDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        VStack(spacing: 0) {
            Rectangle().fill(Color.white.opacity(decor.dark ? 0.14 : 0.16)).frame(height: 1)
            Spacer(minLength: 0)
            Rectangle().fill(Color.black.opacity(decor.dark ? 0.28 : 0.22)).frame(height: 1)
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

/// Rainure gravée Platinum (2 pt) : un trait d'ombre accolé à un trait de lumière.
/// Pour l'en-tête et le pied de page, elle se décale légèrement vers le châssis afin de laisser respirer le puits.
struct PlatinumDivider: View {
    let decor: PlatinumDecor
    let vertical: Bool
    let role: StyleDivider.Role

    var body: some View {
        if vertical {
            HStack(spacing: 0) {
                Rectangle().fill(decor.bevelDark.opacity(decor.dark ? 0.85 : 0.65)).frame(width: 1)
                Rectangle().fill(decor.bevelLight.opacity(decor.dark ? 0.55 : 0.85)).frame(width: 1)
            }
            .frame(width: 2)
            .allowsHitTesting(false)
        } else {
            let inset: CGFloat = role == .plain ? 0 : 2
            let shift: CGFloat = switch role {
            case .header: -2
            case .footer: 2
            case .plain: 0
            }
            VStack(spacing: 0) {
                Rectangle().fill(decor.bevelDark.opacity(decor.dark ? 0.85 : 0.68)).frame(height: 1)
                Rectangle().fill(decor.bevelLight.opacity(decor.dark ? 0.55 : 0.88)).frame(height: 1)
            }
            .frame(height: 2)
            .padding(.horizontal, inset)
            .offset(y: shift)
            .allowsHitTesting(false)
        }
    }
}

/// Tuile symbole en bouton biseauté Platinum : en relief au repos, enfoncé (biseau inversé) une fois choisi.
struct PlatinumTile: View {
    let decor: PlatinumDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        let p = PlatinumPalette.self
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let showDetails = side >= 14
            let corner: CGFloat = showDetails ? 2 : 1
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

            ZStack {
                if selected {
                    shape.fill(decor.depressedFill)
                } else {
                    shape.fill(
                        LinearGradient(
                            colors: decor.dark ? [p.darkButtonTop, p.darkButtonBottom]
                                               : [p.lightButtonTop, p.lightButtonBottom],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Biseau intérieur : normal au repos, inversé une fois choisi (enfoncé).
                if showDetails {
                    Canvas { ctx, size in
                        let insetRect = CGRect(origin: .zero, size: size).insetBy(dx: 1, dy: 1)
                        if selected {
                            drawBevel(in: &ctx, rect: insetRect,
                                      topLeft: Color.black.opacity(0.50),
                                      bottomRight: Color.white.opacity(0.28),
                                      corner: Color.black.opacity(0.25))
                        } else {
                            drawBevel(in: &ctx, rect: insetRect,
                                      topLeft: decor.bevelLight,
                                      bottomRight: decor.bevelDark,
                                      corner: decor.bevelMidDark)
                        }
                    }
                }

                // Bordure extérieure nette d'1 pt.
                shape.strokeBorder(
                    selected ? Color.black.opacity(decor.dark ? 0.75 : 0.55)
                             : (decor.dark ? p.darkBorder : Color(hex: "#333333")),
                    lineWidth: showDetails ? 1 : 0.6
                )

                if showDetails {
                    Image(systemName: name)
                        .font(.system(size: side * 0.46, weight: .semibold))
                        .foregroundStyle(selected ? decor.selectionInk : decor.ink)
                        .offset(x: selected ? 0.5 : 0, y: selected ? 0.5 : 0)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

/// Anneau du logo gravé dans le gris Platinum (léger reflet bas-droit en relief).
struct PlatinumMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        let dark = PlatinumLook.isDark
        let stroke = StrokeStyle(lineWidth: line, lineCap: .round)
        ZStack {
            MarkRing().trim(from: 0, to: progress)
                .stroke(dark ? Color.black.opacity(0.65) : Color.white.opacity(0.85), style: stroke)
                .offset(x: 0.75, y: 0.75)
            MarkRing().trim(from: 0, to: progress)
                .stroke(ink, style: stroke)
        }
    }
}

/// Point du logo en pastille biseautée dans la couleur de surlignage active.
struct PlatinumMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        let d = 2 * radius
        Circle()
            .fill(dot)
            .overlay(alignment: .topLeading) {
                Circle()
                    .fill(Color.white.opacity(0.55))
                    .frame(width: d * 0.34, height: d * 0.34)
                    .offset(x: d * 0.16, y: d * 0.16)
            }
            .overlay {
                Circle().strokeBorder(Color.black.opacity(0.45), lineWidth: max(0.5, line * 0.15))
            }
            .frame(width: d, height: d)
    }
}

/// Réglages › Apparence, quand Atelier Platinum est choisi.
struct PlatinumSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Variante", selection: $settings.platinumMode) {
                ForEach(PlatinumMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 8) {
                Text("Couleur de surlignage")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                HStack(spacing: 10) {
                    ForEach(PlatinumHighlight.allCases) { choice in
                        let selected = settings.platinumHighlight == choice
                        Button {
                            settings.platinumHighlight = choice
                        } label: {
                            HStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 2, style: .continuous)
                                    .fill(choice.swatch)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                                            .strokeBorder(Color.black.opacity(0.45), lineWidth: 1)
                                    }
                                    .frame(width: 14, height: 14)
                                Text(choice.title)
                                    .font(.system(size: 12, weight: selected ? .semibold : .regular))
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .fill(selected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.05))
                            }
                            .overlay {
                                RoundedRectangle(cornerRadius: 4, style: .continuous)
                                    .strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.14),
                                                  lineWidth: selected ? 1.5 : 1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Toggle("Rayures d'en-tête", isOn: $settings.platinumPinstripes)
        } header: {
            Text("Atelier Platinum")
        } footer: {
            Text("Inspiré de l'apparence Platinum de Mac OS 8 et 9 : biseaux d'un pixel, en-tête à rayures, Geneva et quatre couleurs de surlignage.")
        }
    }
}
