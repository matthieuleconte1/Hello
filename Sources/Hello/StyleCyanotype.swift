import AppKit
import SwiftUI

// Cyanotype : un vrai tirage photographique au ferroprussiate, à la manière d'Anna Atkins.
// Le cadre du panneau est une feuille de papier aquarelle ; la zone de résultats est la plage sensibilisée au bleu de
// Prusse, passée au pinceau large (bords irréguliers, densité plus forte au centre, grain du papier) et habitée en
// filigrane par un herbier discret (fougère, algue Dictyota dichotoma, ombelle). Les icônes d'apps deviennent des
// photogrammes blanc-bleuté translucides ; les titres de section sont des légendes manuscrites.
//
// Ce fichier contient tout ce qui est propre au style. Les composants partagés l'appellent par ces points d'entrée :
// `CyanotypeLook` (jetons, mouvement), `CyanotypeDecor` et les vues `Cyanotype…` (décor), `CyanotypeSettings`.

/// Tirage : Atkins (bleu de Prusse profond sur papier ivoire), Délavé (bleu ciel granuleux, clair), Auto ou Nuit.
enum CyanotypeTone: String, CaseIterable, Identifiable {
    case atkins, washed, auto, night
    var id: String { rawValue }

    var title: String {
        switch self {
        case .atkins: "Atkins"
        case .washed: "Délavé"
        case .auto: "Auto"
        case .night: "Nuit"
        }
    }

    /// Le tirage effectivement affiché (« Auto » suit l'apparence du Mac).
    var resolved: CyanotypeTone {
        self == .auto ? (StyleTokens.systemIsDark ? .atkins : .washed) : self
    }
}

/// Ce que le décor du Cyanotype a besoin de savoir pour se dessiner.
struct CyanotypeDecor {
    /// Papier aquarelle du cadre (sert aussi à sculpter les bords au pinceau autour de la plage sensibilisée).
    var frame: Color
    /// Encre du papier (en-tête, pied de page, séparateurs sur marge).
    var paperInk: Color
    /// Couleur de base de la plage sensibilisée (bleu de Prusse ou bleu ciel délavé).
    var pane: Color
    /// Cœur plus dense du tirage, au centre de la plage.
    var paneDeep: Color
    /// Lavis plus clair et granuleux vers les zones moins chargées.
    var paneLight: Color
    /// Léger cerné de pigment accumulé au bord du coup de pinceau.
    var edgePool: Color
    /// Encre du panneau intérieur (blanc-bleuté sur tirage sombre, bleu de Prusse sur Délavé).
    var ink: Color
    /// Couleur de lumière des photogrammes et pastilles.
    var accent: Color
    /// Halo optique autour des silhouettes et de la sélection.
    var glow: Color
    /// Tirage sombre (Atkins, Nuit) ou clair (Délavé).
    var dark: Bool
    /// Marge papier sombre (Nuit) ou claire (Atkins, Délavé).
    var chromeDark: Bool
    /// Filigrane végétal (fougère, algue, ombelle) activé dans les réglages.
    var herbarium: Bool
    /// Couleur et opacité de l'herbier.
    var herbariumColor: Color
    var herbariumOpacity: Double
    /// Grain du papier aquarelle (creux et fibres claires).
    var grainDark: Color
    var grainLight: Color
}

enum CyanotypeLook {
    static let detail = "Tirage photographique au bleu de Prusse, papier aquarelle et herbier en photogramme."
    static let symbol = "leaf.fill"
    static let summary = "le tirage se révèle comme au rinçage : le papier passe du vert-jaune ferreux au bleu de Prusse "
        + "pendant que les silhouettes montent doucement. La sélection glisse sans à-coup ; au lancement, un bref voile "
        + "de surexposition traverse l'image."
    static let effect = "un lavis ferreux vert-jaune se rince sur la plage sensibilisée et révèle brièvement l'herbier."

    struct Palette {
        let frame, paperInk: Color
        let pane, paneDeep, paneLight, edgePool: Color
        let ink, accent, glow: Color
        let selectionFill: Color
        let keyFill, keyBorder, primaryKeyFill, primaryKeyInk: Color
        let toast, live, launchVeil: Color
        let herbariumColor: Color
        let herbariumOpacity: Double
        let dark, chromeDark: Bool
    }

    static func palette(_ tone: CyanotypeTone) -> Palette {
        switch tone.resolved {
        case .washed:
            // Tirage délavé : bleu ciel poudreux et granuleux sur papier coton clair, encre bleu de Prusse.
            Palette(
                frame: Color(hex: "#F4F3EE"), paperInk: Color(hex: "#163558"),
                pane: Color(hex: "#A8C4DC"), paneDeep: Color(hex: "#8AAEC9"),
                paneLight: Color(hex: "#C5D9EA"), edgePool: Color(hex: "#678EB0"),
                ink: Color(hex: "#0C2442"), accent: Color(hex: "#1E4F82"), glow: Color(hex: "#FFFFFF"),
                selectionFill: Color(hex: "#F2F7FB").opacity(0.76),
                keyFill: Color(hex: "#E5EDF4"), keyBorder: Color(hex: "#163558").opacity(0.22),
                primaryKeyFill: Color(hex: "#235485"), primaryKeyInk: Color(hex: "#F7FAFD"),
                toast: Color(hex: "#1C4F82"), live: Color(hex: "#1A528B"), launchVeil: Color(hex: "#FFFFFF"),
                herbariumColor: Color(hex: "#FFFFFF"), herbariumOpacity: 0.56,
                dark: false, chromeDark: false
            )
        case .night:
            // Tirage de nuit : bleu de Prusse presque noir, écritures bleu-argent pour ne pas éblouir.
            Palette(
                frame: Color(hex: "#0E1B2F"), paperInk: Color(hex: "#9BB5D2"),
                pane: Color(hex: "#051021"), paneDeep: Color(hex: "#020914"),
                paneLight: Color(hex: "#0F2547"), edgePool: Color(hex: "#1B3F6E"),
                ink: Color(hex: "#C8DBEE"), accent: Color(hex: "#84BCE2"), glow: Color(hex: "#7FB9E2"),
                selectionFill: Color(hex: "#7BB5DE").opacity(0.20),
                keyFill: Color(hex: "#152742"), keyBorder: Color(hex: "#7FA6CE").opacity(0.22),
                primaryKeyFill: Color(hex: "#1E497A"), primaryKeyInk: Color(hex: "#DFECF9"),
                toast: Color(hex: "#7EB9E0"), live: Color(hex: "#7EB9E0"), launchVeil: Color(hex: "#8EC3E8"),
                herbariumColor: Color(hex: "#A9CEEB"), herbariumOpacity: 0.145,
                dark: true, chromeDark: true
            )
        default:
            // Atkins (par défaut) : bleu de Prusse profond et vivant sur papier chiffon ivoire ancien.
            Palette(
                frame: Color(hex: "#F2ECE0"), paperInk: Color(hex: "#112D54"),
                pane: Color(hex: "#0F3467"), paneDeep: Color(hex: "#09234B"),
                paneLight: Color(hex: "#1C4D8C"), edgePool: Color(hex: "#071E40"),
                ink: Color(hex: "#F2F7FD"), accent: Color(hex: "#B5DCF7"), glow: Color(hex: "#D0EBFF"),
                selectionFill: Color(hex: "#D2EBFF").opacity(0.22),
                keyFill: Color(hex: "#E6DEC9"), keyBorder: Color(hex: "#112D54").opacity(0.22),
                primaryKeyFill: Color(hex: "#11376B"), primaryKeyInk: Color(hex: "#F4EFE5"),
                toast: Color(hex: "#13417E"), live: Color(hex: "#8ED2FA"), launchVeil: Color(hex: "#DEF1FF"),
                herbariumColor: Color(hex: "#EAF5FF"), herbariumOpacity: 0.16,
                dark: true, chromeDark: false
            )
        }
    }

    static var tokens: StyleTokens {
        let settings = AppSettings.shared
        let resolved = settings.cyanotypeTone.resolved
        let p = palette(resolved)
        let photogram = settings.cyanotypePhotogram
        let markDisc: Color = switch resolved {
        case .washed: Color(hex: "#5888B2")
        case .night: Color(hex: "#0F2647")
        default: Color(hex: "#103568")
        }
        let markGlow: Color = switch resolved {
        case .washed: Color(hex: "#FFFFFF")
        case .night: Color(hex: "#B8D6EE")
        default: Color(hex: "#EFF8FF")
        }
        let iconSpec: StyleTokens.IconPhotogram? = photogram
            ? StyleTokens.IconPhotogram(
                dark: p.dark,
                tint: p.dark ? Color(hex: resolved == .night ? "#82AFD4" : "#9ECFF2") : Color(hex: "#2B6096"),
                highlight: p.dark ? Color(hex: resolved == .night ? "#D4E8FA" : "#F4FAFF") : Color(hex: "#174375"),
                glow: p.glow
            )
            : nil

        return StyleTokens(
            surface: .inset(frame: p.frame, pane: p.pane),
            dark: p.dark, ink: p.ink, chromeInk: p.paperInk, chromeDark: p.chromeDark,
            accent: p.accent, accent2: p.glow, live: p.live, toast: p.toast,
            selectionFill: p.selectionFill,
            rowRadius: 7, cellRadius: 11, radius: 15,
            border: (p.paperInk.opacity(p.chromeDark ? 0.16 : 0.14), 1),
            // Pas de filet rectiligne sur la marge papier : le bord passé au pinceau fait la séparation.
            divider: .clear,
            design: .default, titleWeight: .medium, searchWeight: .regular,
            header: .handwritten,
            markSkin: .cyanotype(ink: markDisc, accent: markGlow),
            displayFamily: "Baskerville",
            paneBorder: nil, strongMeta: true,
            keyFill: p.keyFill, keyInk: p.paperInk.opacity(0.82), keyBorder: p.keyBorder,
            primaryKeyFill: p.primaryKeyFill, primaryKeyInk: p.primaryKeyInk,
            launchTint: p.launchVeil,
            tile: .decor,
            iconSaturation: photogram ? 1.0 : 0.82,
            iconOpacity: photogram ? (p.dark ? 0.88 : 0.90) : 0.92,
            motion: .timingCurve(0.25, 0.85, 0.3, 1, duration: 0.22),
            iconPhotogram: iconSpec,
            decor: .cyanotype(CyanotypeDecor(
                frame: p.frame, paperInk: p.paperInk,
                pane: p.pane, paneDeep: p.paneDeep, paneLight: p.paneLight, edgePool: p.edgePool,
                ink: p.ink, accent: p.accent, glow: p.glow,
                dark: p.dark, chromeDark: p.chromeDark, herbarium: settings.cyanotypeHerbarium,
                herbariumColor: p.herbariumColor, herbariumOpacity: p.herbariumOpacity,
                grainDark: p.chromeDark ? Color.black.opacity(0.24) : Color(hex: "#574B36").opacity(0.105),
                grainLight: Color.white.opacity(p.dark ? 0.095 : 0.24)
            ))
        )
    }

    /// Derrière la vignette : table d'atelier sombre ou lin taché de bleu selon le tirage.
    @ViewBuilder static var backdrop: some View {
        switch AppSettings.shared.cyanotypeTone.resolved {
        case .washed:
            LinearGradient(colors: [Color(hex: "#95AEC4"), Color(hex: "#6785A3")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .night:
            LinearGradient(colors: [Color(hex: "#162438"), Color(hex: "#060B14")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        default:
            LinearGradient(colors: [Color(hex: "#1C3557"), Color(hex: "#0D1B30")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Mouvement

    /// Ouverture posée, sans rebond : la feuille apparaît tranquillement pendant le rinçage.
    static func open(light: Bool) -> Animation {
        light ? .easeOut(duration: 0.14) : .timingCurve(0.22, 0.85, 0.3, 1, duration: 0.34)
    }

    static let navigation = Animation.timingCurve(0.28, 0.8, 0.25, 1, duration: 0.24)

    static func modeTransition(forward: Bool) -> AnyTransition {
        let side: CGFloat = forward ? 1 : -1
        return .asymmetric(
            insertion: .offset(x: 10 * Motion.amplitude * side).combined(with: .opacity),
            removal: .opacity
        )
    }

    /// Cascade : les lignes montent en fondu doux, comme une image latente dans le bain.
    static func row(_ order: Int) -> Animation {
        .easeOut(duration: 0.32).delay(0.14 + Double(min(order, 12)) * 0.032)
    }

    static let close = Animation.easeOut(duration: 0.22)
    static var rowOffset: CGSize { CGSize(width: 0, height: 3 * Motion.amplitude) }
    static let rowScale: CGFloat = 1
}

/// Le panneau entier : légère montée douce à l'ouverture ; au lancement d'une app, bref voile clair de surexposition.
struct CyanotypePanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        let k = Motion.amplitude * (light ? 0.35 : 1)
        let flash = min(k, 1.25)
        content
            .brightness(closing ? 0.24 * flash : 0)
            .saturation(closing ? max(0.45, 1 - 0.45 * flash) : 1)
            .scaleEffect(closing ? 1 + 0.008 * k : 1)
            .overlay {
                RoundedRectangle(cornerRadius: PanelLayout.radius, style: .continuous)
                    .fill(Color(hex: "#EAF6FF"))
                    .opacity(closing ? 0.32 * flash : 0)
                    .allowsHitTesting(false)
            }
            .animation(Motion.scaled(CyanotypeLook.close), value: closing)
            .offset(y: hidden ? 4 * k : 0)
            .opacity(hidden ? 0 : 1)
    }
}

// MARK: - Effet d'ouverture : la révélation du tirage

/// Révélation photochimique à l'ouverture : le papier sensibilisé passe du vert-jaune pâle (fer non exposé)
/// au bleu de Prusse au fil d'un rinçage transversal, tandis que les silhouettes d'herbier montent en blanc
/// puis se fondent dans le tirage (≈ 0,76 s à vitesse normale).
struct CyanotypeDevelop: View {
    struct Values {
        /// Progression du rinçage à travers la feuille (0 → 1).
        var rinse: Double = 0
        /// Présence du voile vert-jaune ferreux qui s'oxyde en bleu.
        var ferric: Double = 0
        /// Éclat fugace des silhouettes végétales qui se révèlent en blanc.
        var botanical: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        let t = 1 / Motion.speed
        let amp = Double(min(max(Motion.amplitude, 0.45), 1.25))
        let paneInsetH: CGFloat = (size.width >= 400 ? 8 : 8 * (size.width / 360)) + 4
        let topInset: CGFloat = (size.height >= 260 ? 60 : size.height * 0.21) + 3
        let bottomInset: CGFloat = (size.height >= 260 ? 40 : size.height * 0.14) + 3
        let paneHeight = max(0, size.height - topInset - bottomInset)
        let paneWidth = max(0, size.width - paneInsetH * 2)
        let paneRadius = max(radius - 10, 4)
        let herbariumOn = AppSettings.shared.cyanotypeHerbarium

        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay(alignment: .topLeading) {
                    if (value.ferric > 0.002 || value.botanical > 0.002) && paneHeight > 12 {
                        let wave = UnitPoint(x: -0.60 + value.rinse * 1.85, y: -0.50 + value.rinse * 1.70)
                        let tail = UnitPoint(x: wave.x + 0.55, y: wave.y + 0.45)
                        let ferric = value.ferric * amp
                        ZStack {
                            // Voile vert-jaune ferreux qui s'oxyde en bleu-vert puis s'efface au rinçage.
                            if ferric > 0.002 {
                                LinearGradient(
                                    colors: [
                                        .clear,
                                        Color(hex: "#2B6E82").opacity(0.32 * ferric),
                                        Color(hex: "#B5C878").opacity(0.50 * ferric),
                                        Color(hex: "#CCD98F").opacity(0.42 * ferric),
                                    ],
                                    startPoint: wave,
                                    endPoint: tail
                                )
                                .blendMode(tokens.dark ? .screen : .multiply)
                            }
                            // Révélation blanche de l'herbier pendant le bain, qui redescend vers son filigrane discret.
                            if herbariumOn && value.botanical > 0.002 {
                                Image(nsImage: CyanotypePaper.herbarium)
                                    .renderingMode(.template)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: paneWidth, height: paneHeight)
                                    .foregroundStyle(Color(hex: "#F0F8FF"))
                                    .opacity(value.botanical * amp * (tokens.dark ? 0.28 : 0.42))
                                    .mask {
                                        LinearGradient(
                                            colors: [.white, .white, .clear],
                                            startPoint: .topLeading,
                                            endPoint: tail
                                        )
                                    }
                            }
                        }
                        .frame(width: paneWidth, height: paneHeight)
                        .clipShape(RoundedRectangle(cornerRadius: paneRadius, style: .continuous))
                        .offset(x: paneInsetH, y: topInset)
                    }
                }
            } keyframes: { _ in
                KeyframeTrack(\.rinse) {
                    LinearKeyframe(0, duration: 0.03 * t)
                    CubicKeyframe(1, duration: 0.68 * t)
                }
                KeyframeTrack(\.ferric) {
                    LinearKeyframe(1, duration: 0.03 * t)
                    CubicKeyframe(0.75, duration: 0.28 * t)
                    CubicKeyframe(0, duration: 0.42 * t)
                }
                KeyframeTrack(\.botanical) {
                    LinearKeyframe(0, duration: 0.06 * t)
                    CubicKeyframe(1, duration: 0.24 * t)
                    CubicKeyframe(0, duration: 0.46 * t)
                }
            }
            .allowsHitTesting(false)
    }
}

// MARK: - Matière photographique (calculée une fois et mise en cache)

/// Textures et silhouettes du tirage : grain du papier aquarelle, lavis inégal du ferroprussiate,
/// bords irréguliers passés au pinceau large et herbier botanique (fougère, Dictyota dichotoma, ombelle).
/// Tout est déterministe, calculé une seule fois au premier usage, puis réutilisé sans coût par image.
enum CyanotypePaper {
    /// Creux du papier aquarelle pressé à froid (tuile 160 × 160 pt, teintée par `colorMultiply`).
    static let grainDark: NSImage = makeWatercolorGrain(highlights: false)

    /// Micro-fibres claires du papier coton (tuile 160 × 160 pt).
    static let grainLight: NSImage = makeWatercolorGrain(highlights: true)

    /// Nuages organiques et traces de pinceau larges pour casser l'aplat de la zone sensibilisée (480 × 240).
    static let emulsionClouds: NSImage = makeEmulsionWash(darkPools: false)
    static let emulsionPools: NSImage = makeEmulsionWash(darkPools: true)

    /// Quatre bords passés au pinceau large : la marge papier qui mord irrégulièrement dans le bleu,
    /// et le léger bourrelet de pigment accumulé contre l'arête du pinceau.
    static let edgeTop: NSImage = makeBrushEdge(horizontal: true, fromStart: true, rimOnly: false, seed: 17)
    static let edgeBottom: NSImage = makeBrushEdge(horizontal: true, fromStart: false, rimOnly: false, seed: 41)
    static let edgeLeft: NSImage = makeBrushEdge(horizontal: false, fromStart: true, rimOnly: false, seed: 73)
    static let edgeRight: NSImage = makeBrushEdge(horizontal: false, fromStart: false, rimOnly: false, seed: 109)

    static let rimTop: NSImage = makeBrushEdge(horizontal: true, fromStart: true, rimOnly: true, seed: 17)
    static let rimBottom: NSImage = makeBrushEdge(horizontal: true, fromStart: false, rimOnly: true, seed: 41)
    static let rimLeft: NSImage = makeBrushEdge(horizontal: false, fromStart: true, rimOnly: true, seed: 73)
    static let rimRight: NSImage = makeBrushEdge(horizontal: false, fromStart: false, rimOnly: true, seed: 109)

    /// Planche d'herbier en photogramme blanc translucide (1280 × 640 px @2x) :
    /// grande fronde de fougère à droite, algue *Dictyota dichotoma* en haut à droite, ombelle discrète en bas à gauche.
    static let herbarium: NSImage = makeHerbarium()

    static func tiled(_ image: NSImage, color: Color) -> some View {
        Rectangle()
            .fill(ImagePaint(image: Image(nsImage: image)))
            .colorMultiply(color)
            .allowsHitTesting(false)
    }

    // MARK: Bruit continu déterministe

    private static func hash(_ x: Int, _ y: Int, _ seed: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263 &+ seed &* 1_442_695_041)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h & 0xFFFF) / 65_535.0
    }

    /// Bruit de valeur périodique (raccord parfait pour les tuiles) avec interpolation cubique douce.
    private static func tiledValueNoise(_ x: Double, _ y: Double, periodX: Int, periodY: Int, seed: Int) -> Double {
        let fx = floor(x), fy = floor(y)
        let tx = x - fx, ty = y - fy
        let ux = tx * tx * (3 - 2 * tx)
        let uy = ty * ty * (3 - 2 * ty)
        let x0 = ((Int(fx) % periodX) + periodX) % periodX
        let y0 = ((Int(fy) % periodY) + periodY) % periodY
        let x1 = (x0 + 1) % periodX
        let y1 = (y0 + 1) % periodY
        let a = hash(x0, y0, seed)
        let b = hash(x1, y0, seed)
        let c = hash(x0, y1, seed)
        let d = hash(x1, y1, seed)
        let ab = a + (b - a) * ux
        let cd = c + (d - c) * ux
        return ab + (cd - ab) * uy
    }

    private static func fbm1D(_ t: Double, seed: Int) -> Double {
        var sum = 0.0, amp = 0.55, freq = 1.0
        for octave in 0..<4 {
            let x = t * freq
            let i = Int(floor(x))
            let f = x - floor(x)
            let u = f * f * (3 - 2 * f)
            let v0 = hash(i, octave * 31, seed)
            let v1 = hash(i + 1, octave * 31, seed)
            sum += (v0 + (v1 - v0) * u) * amp
            freq *= 2.15
            amp *= 0.48
        }
        return sum / 1.05
    }

    // MARK: Papier aquarelle et lavis

    /// Grain pressé à froid : alvéoles douces + micro-grain de coton + fines fibres éparses.
    private static func makeWatercolorGrain(highlights: Bool) -> NSImage {
        let side = 160
        guard let ctx = bitmapContext(width: side, height: side),
              let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else {
            return NSImage(size: NSSize(width: side, height: side))
        }
        for y in 0..<side {
            for x in 0..<side {
                let coarse = tiledValueNoise(Double(x) / 16.0, Double(y) / 16.0, periodX: 10, periodY: 10, seed: 13)
                let medium = tiledValueNoise(Double(x) / 5.0, Double(y) / 5.0, periodX: 32, periodY: 32, seed: 29)
                let fine = hash(x, y, 53)
                // Légère anisotropie horizontale, comme le sens des fibres d'un papier chiffon.
                let fiber = tiledValueNoise(Double(x) / 20.0, Double(y) / 2.5, periodX: 8, periodY: 64, seed: 71)
                let combined = coarse * 0.38 + medium * 0.30 + fine * 0.16 + fiber * 0.16
                let alpha: Double
                if highlights {
                    alpha = max(0, (combined - 0.56) / 0.44)
                } else {
                    alpha = max(0, (0.48 - combined) / 0.48)
                }
                let a = UInt8(min(max(alpha * alpha * 255.0, 0), 255))
                let idx = (y * side + x) * 4
                data[idx] = a
                data[idx + 1] = a
                data[idx + 2] = a
                data[idx + 3] = a
            }
        }
        // Quelques fibres de coton microscopiques en surimpression douce.
        ctx.setLineWidth(0.6)
        ctx.setLineCap(.round)
        for i in 0..<(highlights ? 26 : 18) {
            let x0 = hash(i, 1, highlights ? 211 : 223) * Double(side)
            let y0 = hash(i, 2, highlights ? 211 : 223) * Double(side)
            let angle = hash(i, 3, highlights ? 211 : 223) * .pi
            let len = 5.0 + hash(i, 4, highlights ? 211 : 223) * 11.0
            let strength = 0.12 + hash(i, 5, highlights ? 211 : 223) * 0.18
            ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: strength))
            ctx.move(to: CGPoint(x: x0, y: y0))
            ctx.addLine(to: CGPoint(x: x0 + cos(angle) * len, y: y0 + sin(angle) * len))
            ctx.strokePath()
        }
        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: side, height: side)) }
        return NSImage(cgImage: cg, size: NSSize(width: side, height: side))
    }

    /// Variations organiques de la couche de ferroprussiate : passages larges du pinceau et légères flaques.
    private static func makeEmulsionWash(darkPools: Bool) -> NSImage {
        let w = 480, h = 240
        guard let ctx = bitmapContext(width: w, height: h),
              let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else {
            return NSImage(size: NSSize(width: w, height: h))
        }
        for y in 0..<h {
            let ny = Double(y) / Double(h)
            // Trace horizontale douce du pinceau large (spalter).
            let brushBand = fbm1D(ny * 7.5, seed: 307)
            for x in 0..<w {
                let nx = Double(x) / Double(w)
                let cloud1 = tiledValueNoise(nx * 5.0, ny * 3.0, periodX: 6, periodY: 4, seed: 131)
                let cloud2 = tiledValueNoise(nx * 14.0, ny * 8.0, periodX: 16, periodY: 10, seed: 157)
                let mottling = cloud1 * 0.55 + cloud2 * 0.27 + brushBand * 0.18
                // Plus dense vers le centre, un rien plus léger et granuleux vers les bords.
                let dx = (nx - 0.5) * 2.0
                let dy = (ny - 0.5) * 2.0
                let radial = min(1.0, sqrt(dx * dx * 0.72 + dy * dy * 0.92))
                let alpha: Double
                if darkPools {
                    let centerBias = (1.0 - radial * 0.65)
                    let v = max(0, (mottling - 0.36) * 1.35) * centerBias
                    alpha = min(1, v * 0.72)
                } else {
                    let edgeBias = 0.35 + radial * 0.65
                    let v = max(0, (0.62 - mottling) * 1.55) * edgeBias
                    alpha = min(1, v * 0.58)
                }
                let a = UInt8(min(max(alpha * 255.0, 0), 255))
                let idx = (y * w + x) * 4
                data[idx] = a
                data[idx + 1] = a
                data[idx + 2] = a
                data[idx + 3] = a
            }
        }
        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: w, height: h)) }
        return NSImage(cgImage: cg, size: NSSize(width: w / 2, height: h / 2))
    }

    /// Bande de bord passé au pinceau large : passes horizontales irrégulières sur les côtés gauche et droit,
    /// lisière ondulée plus calme en haut et en bas, avec grain de papier et léger bourrelet d'émulsion.
    private static func makeBrushEdge(horizontal: Bool, fromStart: Bool, rimOnly: Bool, seed: Int) -> NSImage {
        let length = horizontal ? 640 : 380
        let depth = horizontal ? 18 : 26
        let w = horizontal ? length : depth
        let h = horizontal ? depth : length
        guard let ctx = bitmapContext(width: w, height: h),
              let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else {
            return NSImage(size: NSSize(width: w / 2, height: h / 2))
        }
        for i in 0..<length {
            let t = Double(i) / Double(length)
            // Mouvement ample de la main + passes distinctes du spalter + rares mèches de poils.
            let broadWave = fbm1D(t * (horizontal ? 5.5 : 4.2), seed: seed)
            let passStep = fbm1D(t * (horizontal ? 16.0 : 12.0), seed: seed + 97)
            let bristles = fbm1D(t * (horizontal ? 40.0 : 68.0), seed: seed + 19)
            let fineHair = hash(i, 7, seed + 53)
            // Aux coins, le papier déborde un rien pour noyer entièrement l'arrondi du conteneur.
            let cornerTaper = max(0, 1.0 - min(t, 1.0 - t) / 0.05)
            let reach: Double
            if horizontal {
                // Lisière supérieure/inférieure : douce ondulation de pinceau avec de discrètes encoches de poils.
                let notch = pow(bristles, 2.0) * 0.30
                reach = 0.22 + broadWave * 0.26 + notch + fineHair * 0.05 + cornerTaper * 0.30
            } else {
                // Côtés gauche/droit : arrêts de passes horizontales du spalter, mèches de poils bien marquées
                // qui balaient la marge entre le bord extérieur et la limite intérieure de 8 pt.
                let spike = pow(bristles, 1.55) * 0.44
                reach = 0.14 + broadWave * 0.18 + passStep * 0.20 + spike + fineHair * 0.05 + cornerTaper * 0.34
            }
            let edgePx = min(Double(depth) - 1.5, max(2.8, reach * Double(depth)))
            let dryBrush = hash(i, 13, seed + 71)
            let dryOutward = hash(i, 29, seed + 137)

            for d in 0..<depth {
                let dist = fromStart ? Double(d) : Double(depth - 1 - d)
                let alpha: Double
                if rimOnly {
                    let delta = dist - edgePx
                    if delta > -1.0 && delta < 4.5 {
                        let bell = exp(-pow((delta - 1.1) / 1.8, 2))
                        alpha = bell * (0.35 + 0.65 * passStep)
                    } else {
                        alpha = 0
                    }
                } else {
                    if dist < edgePx - 2.4 {
                        // Quelques traces sèches de poils bleu qui s'étirent vers l'extérieur dans la marge papier.
                        if !horizontal && cornerTaper < 0.05 && dist > 1.8 && dryOutward > 0.84 {
                            alpha = 0.52 + 0.35 * (edgePx - 2.4 - dist) / max(1.0, edgePx - 4.2)
                        } else {
                            alpha = 1.0
                        }
                    } else if dist < edgePx + 1.8 {
                        let frac = (edgePx + 1.8 - dist) / 4.2
                        let tooth = 0.68 + 0.32 * hash(i, d, seed + 113)
                        alpha = min(1.0, max(0.0, frac * tooth))
                    } else if !horizontal && dist < edgePx + 3.8 && dryBrush > 0.80 {
                        let fade = 1.0 - (dist - (edgePx + 1.8)) / 2.0
                        alpha = fade * 0.44
                    } else {
                        alpha = 0
                    }
                }
                let a = UInt8(min(max(alpha * 255.0, 0), 255))
                let x = horizontal ? i : d
                let y = horizontal ? d : i
                let idx = (y * w + x) * 4
                data[idx] = a
                data[idx + 1] = a
                data[idx + 2] = a
                data[idx + 3] = a
            }
        }
        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: w / 2, height: h / 2)) }
        return NSImage(cgImage: cg, size: NSSize(width: w / 2, height: h / 2))
    }

    // MARK: Herbier botanique (photogrammes en CoreGraphics)

    /// Compose la planche végétale une seule fois : grande fougère à droite, algue *Dictyota dichotoma*
    /// en haut à droite et ombelle fine dans le coin inférieur gauche. Le centre-gauche reste libre pour la lecture.
    private static func makeHerbarium() -> NSImage {
        let w = 1280, h = 640
        guard let ctx = bitmapContext(width: w, height: h) else {
            return NSImage(size: NSSize(width: w / 2, height: h / 2))
        }
        // Repère SwiftUI (y vers le bas) pour placer les spécimens intuitivement par rapport aux coins du panneau.
        ctx.translateBy(x: 0, y: CGFloat(h))
        ctx.scaleBy(x: 1, y: -1)
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)

        // Passe 1 : halo optique diffus de tirage par contact (lumière qui contourne légèrement les bords végétaux).
        ctx.saveGState()
        ctx.setShadow(offset: .zero, blur: 10, color: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
        drawSpecimens(in: ctx, size: CGSize(width: w, height: h), haloPass: true)
        ctx.restoreGState()

        // Passe 2 : silhouettes translucides superposées (les chevauchements deviennent plus blancs, comme les callas).
        drawSpecimens(in: ctx, size: CGSize(width: w, height: h), haloPass: false)

        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: w / 2, height: h / 2)) }
        let image = NSImage(cgImage: cg, size: NSSize(width: w / 2, height: h / 2))
        image.isTemplate = true
        return image
    }

    private static func drawSpecimens(in ctx: CGContext, size: CGSize, haloPass: Bool) {
        let scale: CGFloat = haloPass ? 0.45 : 1.0
        // 1. Grande fronde de fougère courbée depuis le coin inférieur droit vers le haut droit.
        drawFernFrond(
            in: ctx,
            start: CGPoint(x: size.width * 0.96, y: size.height * 1.04),
            control: CGPoint(x: size.width * 0.89, y: size.height * 0.50),
            end: CGPoint(x: size.width * 0.75, y: size.height * 0.08),
            maxSpread: size.height * 0.26,
            pairs: 26,
            opacity: 0.68 * scale
        )
        // 2. Algue Dictyota dichotoma (hommage à Anna Atkins) : rubans translucides qui fourchent en Y en haut à droite.
        drawDichotomousAlgae(
            in: ctx,
            origin: CGPoint(x: size.width * 1.01, y: size.height * 0.16),
            angle: .pi * 0.86,
            length: size.height * 0.175,
            width: 10.5,
            depth: 5,
            seed: 19,
            opacity: 0.36 * scale
        )
        drawDichotomousAlgae(
            in: ctx,
            origin: CGPoint(x: size.width * 0.89, y: -size.height * 0.02),
            angle: .pi * 0.64,
            length: size.height * 0.145,
            width: 8.5,
            depth: 4,
            seed: 47,
            opacity: 0.32 * scale
        )
        // 3. Ombelle légère (carotte sauvage) qui s'épanouit en bas au centre-droit, hors de la zone de texte.
        drawUmbel(
            in: ctx,
            stemBase: CGPoint(x: size.width * 0.55, y: size.height * 1.06),
            head: CGPoint(x: size.width * 0.65, y: size.height * 0.78),
            radius: size.height * 0.155,
            opacity: 0.50 * scale
        )
        // 4. Petite pousse de fougère dans le coin inférieur droit pour ancrer la composition.
        drawFernFrond(
            in: ctx,
            start: CGPoint(x: size.width * 1.01, y: size.height * 0.96),
            control: CGPoint(x: size.width * 0.86, y: size.height * 0.90),
            end: CGPoint(x: size.width * 0.73, y: size.height * 0.78),
            maxSpread: size.height * 0.115,
            pairs: 14,
            opacity: 0.48 * scale
        )
    }

    /// Fronde de fougère réaliste : rachis en courbe de Bézier, pennes alternées effilées et pinnules lobées.
    private static func drawFernFrond(in ctx: CGContext, start: CGPoint, control: CGPoint, end: CGPoint,
                                      maxSpread: CGFloat, pairs: Int, opacity: CGFloat) {
        // Rachis principal (tige centrale légèrement plus opaque).
        ctx.saveGState()
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity * 0.92))
        ctx.setLineWidth(2.6)
        ctx.setLineCap(.round)
        ctx.move(to: start)
        ctx.addQuadCurve(to: end, control: control)
        ctx.strokePath()
        ctx.restoreGState()

        for i in 1...pairs {
            let t = CGFloat(i) / CGFloat(pairs + 1)
            let tang = quadTangent(start, control, end, t)
            let baseAngle = atan2(tang.y, tang.x)
            // Enveloppe naturelle d'une fronde : plus large au tiers inférieur, effilée à la pointe.
            let envelope = sin(pow(t, 0.72) * .pi) * (1.0 - 0.10 * t)
            let pinnaLen = maxSpread * envelope
            guard pinnaLen > 7 else { continue }

            for side in [-1.0, 1.0] {
                let stagger = side > 0 ? 0.0 : 0.011
                let ps = quadPoint(start, control, end, min(0.98, t + stagger))
                let splay = (1.10 - 0.34 * t) * CGFloat(side)
                let angle = baseAngle + splay
                let tip = CGPoint(x: ps.x + cos(angle) * pinnaLen, y: ps.y + sin(angle) * pinnaLen)
                let ctrl = CGPoint(
                    x: (ps.x + tip.x) * 0.5 + cos(baseAngle) * pinnaLen * 0.20,
                    y: (ps.y + tip.y) * 0.5 + sin(baseAngle) * pinnaLen * 0.20
                )
                drawPinna(in: ctx, base: ps, control: ctrl, tip: tip, length: pinnaLen, opacity: opacity)
            }
        }
    }

    /// Une penne de fougère : nervure fine garnie de pinnules serrées qui forment une silhouette plumeuse continue.
    private static func drawPinna(in ctx: CGContext, base: CGPoint, control: CGPoint, tip: CGPoint,
                                  length: CGFloat, opacity: CGFloat) {
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity * 0.72))
        ctx.setLineWidth(max(1.0, length * 0.015))
        ctx.move(to: base)
        ctx.addQuadCurve(to: tip, control: control)
        ctx.strokePath()

        let lobes = max(5, Int(length / 7.5))
        for j in 0..<lobes {
            let u = (CGFloat(j) + 0.38) / CGFloat(lobes)
            let c = quadPoint(base, control, tip, u)
            let tang = quadTangent(base, control, tip, u)
            let a = atan2(tang.y, tang.x)
            let lobeLen = (length * 0.21) * (1.0 - u * 0.70) * (0.82 + 0.18 * sin(u * .pi))
            let lobeW = lobeLen * 0.48
            for side in [-1.0, 1.0] {
                let la = a + CGFloat(side) * 0.84
                drawLeaflet(in: ctx, at: c, angle: la, length: lobeLen, width: lobeW, opacity: opacity * 0.88)
            }
        }
        // Foliole terminale.
        let endTang = quadTangent(base, control, tip, 0.95)
        drawLeaflet(in: ctx, at: tip, angle: atan2(endTang.y, endTang.x), length: max(5, length * 0.13),
                    width: max(2.5, length * 0.055), opacity: opacity * 0.82)
    }

    private static func drawLeaflet(in ctx: CGContext, at origin: CGPoint, angle: CGFloat,
                                    length: CGFloat, width: CGFloat, opacity: CGFloat) {
        let ca = cos(angle), sa = sin(angle)
        let nx = -sa, ny = ca
        let tip = CGPoint(x: origin.x + ca * length, y: origin.y + sa * length)
        let c1 = CGPoint(x: origin.x + ca * length * 0.48 + nx * width,
                         y: origin.y + sa * length * 0.48 + ny * width)
        let c2 = CGPoint(x: origin.x + ca * length * 0.48 - nx * width,
                         y: origin.y + sa * length * 0.48 - ny * width)
        ctx.beginPath()
        ctx.move(to: origin)
        ctx.addQuadCurve(to: tip, control: c1)
        ctx.addQuadCurve(to: origin, control: c2)
        ctx.closePath()
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity))
        ctx.fillPath()
    }

    /// Algue marine ramifiée par dichotomie (*Dictyota dichotoma*) : rubans souples et translucides qui se divisent.
    private static func drawDichotomousAlgae(in ctx: CGContext, origin: CGPoint, angle: CGFloat,
                                             length: CGFloat, width: CGFloat, depth: Int, seed: Int, opacity: CGFloat) {
        guard depth > 0 else { return }
        let bend = (hash(depth, seed, 313) - 0.5) * 0.32
        let midAngle = angle + bend * 0.5
        let endAngle = angle + bend
        let end = CGPoint(x: origin.x + cos(endAngle) * length, y: origin.y + sin(endAngle) * length)
        let ctrl = CGPoint(x: origin.x + cos(midAngle) * length * 0.52, y: origin.y + sin(midAngle) * length * 0.52)

        // Ruban plat légèrement évasé avant la fourche, comme une vraie lame d'algue.
        let perp0 = CGPoint(x: -sin(angle) * width * 0.45, y: cos(angle) * width * 0.45)
        let perp1 = CGPoint(x: -sin(endAngle) * width * 0.58, y: cos(endAngle) * width * 0.58)
        ctx.beginPath()
        ctx.move(to: CGPoint(x: origin.x + perp0.x, y: origin.y + perp0.y))
        ctx.addQuadCurve(to: CGPoint(x: end.x + perp1.x, y: end.y + perp1.y),
                         control: CGPoint(x: ctrl.x + perp0.x * 1.1, y: ctrl.y + perp0.y * 1.1))
        ctx.addLine(to: CGPoint(x: end.x - perp1.x, y: end.y - perp1.y))
        ctx.addQuadCurve(to: CGPoint(x: origin.x - perp0.x, y: origin.y - perp0.y),
                         control: CGPoint(x: ctrl.x - perp0.x * 1.1, y: ctrl.y - perp0.y * 1.1))
        ctx.closePath()
        ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity))
        ctx.fillPath()

        let spread = 0.36 + hash(depth, seed, 331) * 0.18
        let nextLen = length * (0.72 + hash(depth, seed, 347) * 0.14)
        let nextW = max(2.2, width * 0.78)
        drawDichotomousAlgae(in: ctx, origin: end, angle: endAngle - spread, length: nextLen,
                             width: nextW, depth: depth - 1, seed: seed &* 3 + 1, opacity: opacity * 0.95)
        drawDichotomousAlgae(in: ctx, origin: end, angle: endAngle + spread * 0.92, length: nextLen * 0.94,
                             width: nextW, depth: depth - 1, seed: seed &* 5 + 2, opacity: opacity * 0.95)
    }

    /// Ombelle radiale (carotte sauvage) : tige fine, rayons primaires, ombellules étoilées.
    private static func drawUmbel(in ctx: CGContext, stemBase: CGPoint, head: CGPoint,
                                  radius: CGFloat, opacity: CGFloat) {
        let stemCtrl = CGPoint(x: (stemBase.x + head.x) * 0.5 - 12, y: (stemBase.y + head.y) * 0.5 + 8)
        ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity * 0.85))
        ctx.setLineWidth(2.0)
        ctx.setLineCap(.round)
        ctx.move(to: stemBase)
        ctx.addQuadCurve(to: head, control: stemCtrl)
        ctx.strokePath()

        let rays = 11
        for i in 0..<rays {
            let frac = CGFloat(i) / CGFloat(rays - 1)
            let angle = -CGFloat.pi * 0.88 + frac * CGFloat.pi * 0.78
            let rayLen = radius * (0.74 + 0.28 * sin(frac * .pi))
            let end = CGPoint(x: head.x + cos(angle) * rayLen, y: head.y + sin(angle) * rayLen)
            let ctrl = CGPoint(
                x: (head.x + end.x) * 0.5 + cos(angle + .pi / 2) * (frac - 0.5) * 14,
                y: (head.y + end.y) * 0.5 + sin(angle + .pi / 2) * (frac - 0.5) * 14
            )
            ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity * 0.68))
            ctx.setLineWidth(1.1)
            ctx.move(to: head)
            ctx.addQuadCurve(to: end, control: ctrl)
            ctx.strokePath()

            // Ombellule terminale : couronne de fleurettes blanches translucides.
            let florets = 7
            let subR = radius * 0.16
            for f in 0..<florets {
                let fa = CGFloat(f) / CGFloat(florets) * 2 * .pi + CGFloat(i) * 0.4
                let r = subR * (0.65 + 0.35 * CGFloat(hash(i, f, 409)))
                let fx = end.x + cos(fa) * r
                let fy = end.y + sin(fa) * r
                ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity * 0.55))
                ctx.setLineWidth(0.7)
                ctx.move(to: end)
                ctx.addLine(to: CGPoint(x: fx, y: fy))
                ctx.strokePath()
                let dotR: CGFloat = 2.6 + CGFloat(hash(i, f, 421)) * 2.2
                ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: opacity * 0.9))
                ctx.fillEllipse(in: CGRect(x: fx - dotR, y: fy - dotR, width: dotR * 2, height: dotR * 2))
            }
        }
    }

    private static func quadPoint(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ t: CGFloat) -> CGPoint {
        let mt = 1 - t
        return CGPoint(
            x: mt * mt * p0.x + 2 * mt * t * p1.x + t * t * p2.x,
            y: mt * mt * p0.y + 2 * mt * t * p1.y + t * t * p2.y
        )
    }

    private static func quadTangent(_ p0: CGPoint, _ p1: CGPoint, _ p2: CGPoint, _ t: CGFloat) -> CGPoint {
        CGPoint(
            x: 2 * (1 - t) * (p1.x - p0.x) + 2 * t * (p2.x - p1.x),
            y: 2 * (1 - t) * (p1.y - p0.y) + 2 * t * (p2.y - p1.y)
        )
    }

    private static func bitmapContext(width: Int, height: Int) -> CGContext? {
        CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )
    }
}

// MARK: - Décor du panneau

/// Le cadre : papier aquarelle pressé à froid, grain doux et léger relief de feuille épaisse.
struct CyanotypeSurface: View {
    let decor: CyanotypeDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            // Légère lumière rasante naturelle sur la feuille de papier chiffon.
            LinearGradient(
                colors: [
                    Color.white.opacity(decor.chromeDark ? 0.035 : 0.14),
                    .clear,
                    Color.black.opacity(decor.chromeDark ? 0.10 : 0.035),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            CyanotypePaper.tiled(CyanotypePaper.grainDark, color: decor.grainDark)
            CyanotypePaper.tiled(CyanotypePaper.grainLight, color: decor.grainLight)
            // Doux filet intérieur clair, comme l'épaisseur d'un papier coton 300 g.
            shape.strokeBorder(Color.white.opacity(decor.chromeDark ? 0.05 : 0.45), lineWidth: 1)
                .padding(0.5)
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

/// Le panneau intérieur : plage sensibilisée au bleu de Prusse (plus dense au centre, lavis nuancé, grain du papier),
/// herbier discret en photogramme et bords déchiquetés au pinceau qui rejoignent la marge de papier aquarelle.
struct CyanotypePane: View {
    let decor: CyanotypeDecor
    let radius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            // Bords contenus dans la marge intérieure de la liste (8 pt) pour ne jamais mordre sur la sélection.
            let edgeH = min(6.6, max(2.2, h * 0.043))
            let edgeV = min(8.0, max(2.4, w * 0.0145))

            ZStack {
                // Densité centrale plus profonde, comme un tirage exposé en plein soleil.
                RadialGradient(
                    colors: [decor.paneDeep.opacity(0.62), .clear, decor.paneLight.opacity(0.32)],
                    center: UnitPoint(x: 0.46, y: 0.48),
                    startRadius: min(w, h) * 0.08,
                    endRadius: max(w, h) * 0.72
                )

                // Nuages de lavis et flaques d'émulsion passée au pinceau large.
                Image(nsImage: CyanotypePaper.emulsionPools)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(decor.paneDeep)
                    .opacity(decor.dark ? 0.46 : 0.40)

                Image(nsImage: CyanotypePaper.emulsionClouds)
                    .renderingMode(.template)
                    .resizable()
                    .foregroundStyle(decor.paneLight)
                    .opacity(decor.dark ? 0.36 : 0.44)

                // Granulation du ferroprussiate dans le grain du papier aquarelle.
                CyanotypePaper.tiled(CyanotypePaper.grainDark,
                                     color: decor.paneDeep.opacity(decor.dark ? 0.34 : 0.22))
                CyanotypePaper.tiled(CyanotypePaper.grainLight,
                                     color: decor.glow.opacity(decor.dark ? 0.065 : 0.24))

                // Version végétale : silhouettes botaniques en filigrane très discret.
                if decor.herbarium {
                    Image(nsImage: CyanotypePaper.herbarium)
                        .renderingMode(.template)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: w, height: h)
                        .clipped()
                        .foregroundStyle(decor.herbariumColor)
                        .opacity(decor.herbariumOpacity)
                }

                // Léger bourrelet de pigment accumulé juste au bord du coup de pinceau.
                brushRim(width: w, height: h, edgeH: edgeH, edgeV: edgeV)

                // Marge de papier aquarelle qui mord en franges de pinceau tout autour du tirage.
                brushMargin(width: w, height: h, edgeH: edgeH, edgeV: edgeV)
            }
        }
        .allowsHitTesting(false)
    }

    private func brushRim(width w: CGFloat, height h: CGFloat, edgeH: CGFloat, edgeV: CGFloat) -> some View {
        let opacity: Double = decor.dark ? 0.45 : 0.34
        return ZStack {
            VStack(spacing: 0) {
                Image(nsImage: CyanotypePaper.rimTop).renderingMode(.template).resizable()
                    .frame(width: w, height: edgeH)
                Spacer(minLength: 0)
                Image(nsImage: CyanotypePaper.rimBottom).renderingMode(.template).resizable()
                    .frame(width: w, height: edgeH)
            }
            HStack(spacing: 0) {
                Image(nsImage: CyanotypePaper.rimLeft).renderingMode(.template).resizable()
                    .frame(width: edgeV, height: h)
                Spacer(minLength: 0)
                Image(nsImage: CyanotypePaper.rimRight).renderingMode(.template).resizable()
                    .frame(width: edgeV, height: h)
            }
        }
        .foregroundStyle(decor.edgePool)
        .opacity(opacity)
    }

    private func brushMargin(width w: CGFloat, height h: CGFloat, edgeH: CGFloat, edgeV: CGFloat) -> some View {
        ZStack {
            VStack(spacing: 0) {
                Image(nsImage: CyanotypePaper.edgeTop).renderingMode(.template).resizable()
                    .frame(width: w, height: edgeH)
                Spacer(minLength: 0)
                Image(nsImage: CyanotypePaper.edgeBottom).renderingMode(.template).resizable()
                    .frame(width: w, height: edgeH)
            }
            HStack(spacing: 0) {
                Image(nsImage: CyanotypePaper.edgeLeft).renderingMode(.template).resizable()
                    .frame(width: edgeV, height: h)
                Spacer(minLength: 0)
                Image(nsImage: CyanotypePaper.edgeRight).renderingMode(.template).resizable()
                    .frame(width: edgeV, height: h)
            }
        }
        .foregroundStyle(decor.frame)
    }
}

/// Sélection : zone « surexposée » laiteuse et douce (comme une bandelette de papier calque posée sur le tirage
/// d'Atkins), aux bords fondus dans le grain du papier — sans filet rigide ni crochet technique.
struct CyanotypeSelection: View {
    let decor: CyanotypeDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            // Doux dégradé laiteux, un rien plus lumineux au centre de la bandelette.
            shape.fill(
                LinearGradient(
                    colors: [
                        decor.glow.opacity(decor.dark ? 0.09 : 0.22),
                        decor.glow.opacity(decor.dark ? 0.17 : 0.36),
                        decor.glow.opacity(decor.dark ? 0.07 : 0.16),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            // Le grain du papier se prolonge dans la zone surexposée.
            CyanotypePaper.tiled(CyanotypePaper.grainLight, color: decor.glow.opacity(decor.dark ? 0.07 : 0.22))
                .clipShape(shape)
            // Halo de bord diffus, comme la lumière qui déborde sous une bandelette de calque.
            shape.strokeBorder(
                decor.dark ? decor.glow.opacity(0.32) : Color.white.opacity(0.65),
                lineWidth: 1.5
            )
            .blur(radius: 1.2)
        }
        .shadow(color: decor.glow.opacity(decor.dark ? 0.24 : 0.38), radius: 5.5)
        .allowsHitTesting(false)
    }
}

/// Séparateur vertical en trait de pinceau ténu dans les vues scindées (presse-papiers, couleurs).
/// Horizontalement, la marge papier et le bord passé au pinceau suffisent sans trait rectiligne.
struct CyanotypeDivider: View {
    let decor: CyanotypeDecor
    let vertical: Bool

    var body: some View {
        if vertical {
            let ink = decor.ink.opacity(0.24)
            LinearGradient(colors: [.clear, ink, ink, .clear], startPoint: .top, endPoint: .bottom)
                .allowsHitTesting(false)
        }
    }
}

/// Pastille d'un symbole : silhouette blanche translucide sur lavis cyanotype ; choisie, elle prend la lumière.
struct CyanotypeTile: View {
    let decor: CyanotypeDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 6, style: .continuous)
        let fill: Color = decor.dark
            ? decor.glow.opacity(selected ? 0.26 : 0.12)
            : (selected ? decor.accent : Color.white.opacity(0.58))
        let stroke: Color = decor.dark
            ? decor.glow.opacity(selected ? 0.52 : 0.24)
            : (selected ? decor.accent : decor.accent.opacity(0.22))
        let glyphColor: Color = decor.dark
            ? (selected ? Color(hex: "#F5FAFF") : decor.ink.opacity(0.88))
            : (selected ? Color(hex: "#F7FAFD") : decor.ink.opacity(0.84))

        shape
            .fill(fill)
            .overlay(shape.strokeBorder(stroke, lineWidth: 0.85))
            .overlay(
                Image(systemName: name)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .medium))
                    .foregroundStyle(glyphColor)
                    .shadow(color: decor.glow.opacity(decor.dark ? (selected ? 0.65 : 0.30) : 0),
                            radius: selected ? 3.5 : 1.8)
            )
            .padding(1.5)
            .scaleEffect(selected ? 1.04 : 1)
            .animation(Motion.scaled(.easeOut(duration: 0.18)), value: selected)
    }
}

// MARK: - Logo en photogramme

/// L'anneau en photogramme blanc translucide avec halo, exposé sur une petite pastille ronde de bleu de Prusse.
struct CyanotypeMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let accent: Color

    var body: some View {
        let trimmed = MarkRing().trim(from: 0, to: progress)
        ZStack {
            // Petite goutte sensibilisée au bleu de Prusse aux bords fondus dans le papier coton.
            Circle()
                .fill(
                    RadialGradient(
                        stops: [
                            .init(color: ink, location: 0),
                            .init(color: ink.opacity(0.95), location: 0.78),
                            .init(color: ink.opacity(0.65), location: 0.94),
                            .init(color: ink.opacity(0), location: 1.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(8, line * 4.9)
                    )
                )
                .scaleEffect(1.34)
            // Halo optique diffus autour de la silhouette blanche.
            trimmed
                .stroke(accent.opacity(0.45), style: StrokeStyle(lineWidth: line * 1.55, lineCap: .round))
                .blur(radius: max(0.8, line * 0.45))
            // Corps translucide du photogramme.
            trimmed
                .stroke(accent.opacity(0.84), style: StrokeStyle(lineWidth: line, lineCap: .round))
            // Cœur plus blanc, comme l'épaisseur la plus opaque du sujet.
            trimmed
                .stroke(Color.white.opacity(0.65), style: StrokeStyle(lineWidth: line * 0.42, lineCap: .round))
        }
    }
}

/// Le point du logo : même photogramme blanc translucide entouré de son halo lumineux.
struct CyanotypeMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let accent: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(accent.opacity(0.5))
                .frame(width: 2.9 * radius, height: 2.9 * radius)
                .blur(radius: max(0.8, radius * 0.65))
            Circle()
                .fill(accent.opacity(0.90))
                .frame(width: 2 * radius, height: 2 * radius)
            Circle()
                .fill(Color.white.opacity(0.72))
                .frame(width: 1.05 * radius, height: 1.05 * radius)
        }
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
            Toggle("Herbier", isOn: $settings.cyanotypeHerbarium)
            Toggle("Icônes en photogramme", isOn: $settings.cyanotypePhotogram)
        } header: { Text("Cyanotype") } footer: {
            Text("L'herbier pose en filigrane une fougère, une algue et une ombelle sur le tirage. En photogramme, les icônes d'apps deviennent des silhouettes translucides.")
        }
    }
}
