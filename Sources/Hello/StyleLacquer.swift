import AppKit
import SwiftUI

// Laque : d'après la laque japonaise urushi (roiro-nuri) et la réparation à l'or kintsugi.
// Noir d'ébène chaud et satiné, lustre discret en haut du panneau, filets d'or fin, sélection réchauffée
// soulignée d'un fil d'or plus lumineux au centre, tuiles cerclées d'or et logo réparé au kintsugi.
// En Porcelaine : porcelaine mate et or mat. En Cinabre : brun laqué rouge très sombre (#1D0F0D).
//
// Tout ce qui est propre au style vit ici. Les composants partagés l'appellent par ces points d'entrée :
// `LacquerLook` (jetons, mouvement, réglages), `LacquerDecor` et les vues `Lacquer…` (décor), `LacquerSettings` (Réglages › Apparence).

/// Variante de la peau (« Auto » suit l'apparence du Mac : Urushi en sombre, Porcelaine en clair).
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

    /// Variante effectivement affichée (« Auto » suit l'apparence courante du Mac).
    var resolved: LacquerMode {
        self == .auto ? (StyleTokens.systemIsDark ? .urushi : .porcelain) : self
    }
}

/// Palette de chaque variante : ébène urushi, porcelaine mate, ou laque cinabre profonde.
private enum LacquerPalette {
    struct Spec {
        let dark: Bool
        let frame: Color
        let pane: Color
        let ink: Color
        let secondary: Color
        let gold: Color
        let goldBright: Color
        let goldDeep: Color
        let selection: Color
        let keyFill: Color
        let keyBorder: Color
        let primaryKeyFill: Color
        let primaryKeyInk: Color
        let iconButtonFill: Color
        let iconButtonInk: Color
        let tileRestFill: Color
        let tileSelectedFill: Color
    }

    static func spec(for mode: LacquerMode) -> Spec {
        switch mode.resolved {
        case .porcelain:
            // Porcelaine mate et or mat : crème minérale chaude, encre charbon doux, or brossé.
            Spec(
                dark: false,
                frame: Color(hex: "#E7E2D8"),
                pane: Color(hex: "#F5F2EB"),
                ink: Color(hex: "#1D1A17"),
                secondary: Color(hex: "#797065"),
                gold: Color(hex: "#AF8635"),
                goldBright: Color(hex: "#C89B3C"),
                goldDeep: Color(hex: "#7A581B"),
                selection: Color(hex: "#EAE3D5"),
                keyFill: Color(hex: "#ECE7DC"),
                keyBorder: Color(hex: "#AF8635").opacity(0.32),
                primaryKeyFill: Color(hex: "#AF8635"),
                primaryKeyInk: Color(hex: "#FAF7F0"),
                iconButtonFill: Color(hex: "#DDD6C8"),
                iconButtonInk: Color(hex: "#7A581B"),
                tileRestFill: Color(hex: "#EFEAE0"),
                tileSelectedFill: Color(hex: "#E2D7C0")
            )
        case .cinnabar:
            // Cinabre (shunkei / negoro) : brun laqué rouge très sombre (#1D0F0D), or chaud lumineux.
            Spec(
                dark: true,
                frame: Color(hex: "#130908"),
                pane: Color(hex: "#1D0F0D"),
                ink: Color(hex: "#F2E9DF"),
                secondary: Color(hex: "#9B8379"),
                gold: Color(hex: "#DCB666"),
                goldBright: Color(hex: "#F7DC94"),
                goldDeep: Color(hex: "#8F6A29"),
                selection: Color(hex: "#2D1714"),
                keyFill: Color(hex: "#271411"),
                keyBorder: Color(hex: "#DCB666").opacity(0.26),
                primaryKeyFill: Color(hex: "#DCB666"),
                primaryKeyInk: Color(hex: "#1D0F0D"),
                iconButtonFill: Color(hex: "#2F1916"),
                iconButtonInk: Color(hex: "#E2BE72"),
                tileRestFill: Color(hex: "#241310"),
                tileSelectedFill: Color(hex: "#3A1F19")
            )
        default:
            // Urushi : noir d'ébène chaud et satiné, ivoire doux et or fin.
            Spec(
                dark: true,
                frame: Color(hex: "#0A0908"),
                pane: Color(hex: "#141210"),
                ink: Color(hex: "#F0EAE0"),
                secondary: Color(hex: "#8D8476"),
                gold: Color(hex: "#D4AF63"),
                goldBright: Color(hex: "#F3D68D"),
                goldDeep: Color(hex: "#8A6A2C"),
                selection: Color(hex: "#221E18"),
                keyFill: Color(hex: "#1D1A16"),
                keyBorder: Color(hex: "#D4AF63").opacity(0.24),
                primaryKeyFill: Color(hex: "#D4AF63"),
                primaryKeyInk: Color(hex: "#141210"),
                iconButtonFill: Color(hex: "#221E19"),
                iconButtonInk: Color(hex: "#DBB86E"),
                tileRestFill: Color(hex: "#1B1814"),
                tileSelectedFill: Color(hex: "#2F271C")
            )
        }
    }
}

/// Ce que le décor de la peau a besoin de savoir pour se dessiner.
struct LacquerDecor {
    var dark: Bool
    var mode: LacquerMode
    var frame: Color
    var pane: Color
    var ink: Color
    var secondary: Color
    var accent: Color
    var goldBright: Color
    var goldDeep: Color
    var tileRestFill: Color
    var tileSelectedFill: Color
    var kintsugi: Bool
    var sheen: Bool
    var grain = true
}

enum LacquerLook {
    static let detail = "Laque urushi et kintsugi : ébène satiné, porcelaine mate et fil d'or."
    static let symbol = "seal"
    static let summary = "le panneau s'ouvre depuis le centre comme un paravent, le long d'un fil d'or kintsugi ; les lignes se posent lentement."
    static let effect = "un fil d'or kintsugi part du centre sous la recherche, s'étend, brille puis se pose doucement."

    /// Variante sombre active (Urushi et Cinabre sont sombres ; Porcelaine est claire).
    static var isDark: Bool {
        let mode = AppSettings.shared.lacquerMode.resolved
        return mode == .urushi || mode == .cinnabar
    }

    /// Ce qui change l'aspect du champ de recherche.
    static var signature: String {
        let s = AppSettings.shared
        return "\(s.lacquerMode.rawValue)|\(s.lacquerKintsugi)|\(s.lacquerSheen)|\(s.lacquerGrain)"
    }

    /// « Réinitialiser l'apparence » : remet les réglages de la peau par défaut.
    static func resetSettings(_ s: AppSettings) {
        s.lacquerMode = .auto
        s.lacquerKintsugi = true
        s.lacquerSheen = true
        s.lacquerGrain = true
    }

    static var tokens: StyleTokens {
        let settings = AppSettings.shared
        let resolved = settings.lacquerMode.resolved
        let p = LacquerPalette.spec(for: resolved)
        let decor = LacquerDecor(
            dark: p.dark,
            mode: resolved,
            frame: p.frame,
            pane: p.pane,
            ink: p.ink,
            secondary: p.secondary,
            accent: p.gold,
            goldBright: p.goldBright,
            goldDeep: p.goldDeep,
            tileRestFill: p.tileRestFill,
            tileSelectedFill: p.tileSelectedFill,
            kintsugi: settings.lacquerKintsugi,
            sheen: settings.lacquerSheen,
            grain: settings.lacquerGrain
        )

        return StyleTokens(
            surface: .inset(frame: p.frame, pane: p.pane),
            dark: p.dark,
            ink: p.ink,
            chromeInk: p.ink,
            chromeDark: p.dark,
            accent: p.gold,
            accent2: p.goldBright,
            live: p.gold,
            toast: p.gold,
            selectionFill: p.selection,
            selectionInk: nil,
            rowRadius: 8,
            cellRadius: 11,
            radius: 16,
            // Bordure 1 pt en dégradé doré (30 % en haut → 8 % en bas) dessinée par `LacquerSurface`.
            border: nil,
            // Séparateurs dorés fondus dessinés par `LacquerDivider`.
            divider: .clear,
            design: .default,
            titleWeight: .regular,
            searchWeight: .regular,
            header: .label,
            markSkin: .lacquer(ink: p.ink, dot: p.gold),
            // Optima pour la recherche (installée sur macOS) ; SF Pro pour les lignes (`fontFamily: nil`).
            displayFamily: "Optima",
            paneBorder: nil,
            iconButton: (fill: p.iconButtonFill, ink: p.iconButtonInk),
            strongMeta: true,
            keyFill: p.keyFill,
            keyInk: p.ink.opacity(p.dark ? 0.84 : 0.78),
            keyBorder: p.keyBorder,
            primaryKeyFill: p.primaryKeyFill,
            primaryKeyInk: p.primaryKeyInk,
            launchTint: p.gold,
            tile: .decor,
            // Couleurs d'icônes adoucies à 85 % au repos, pleine présence à la sélection.
            iconSaturation: 0.85,
            iconOpacity: 0.90,
            // Sélection lente et calme (220 ms).
            motion: .timingCurve(0.25, 0.85, 0.3, 1, duration: 0.22),
            decor: .lacquer(decor)
        )
    }

    /// Fond derrière la vignette et les aperçus : bois sombre brûlé, soie grège ou laque bordeaux.
    @ViewBuilder static var backdrop: some View {
        switch AppSettings.shared.lacquerMode.resolved {
        case .porcelain:
            LinearGradient(
                colors: [Color(hex: "#BCB4A6"), Color(hex: "#968E81")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        case .cinnabar:
            LinearGradient(
                colors: [Color(hex: "#3E221D"), Color(hex: "#180B09")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
            LinearGradient(
                colors: [Color(hex: "#302B24"), Color(hex: "#14110E")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    // MARK: Mouvement (paravent shoji)

    /// Paravent : les vantaux s'écartent en 460 ms, départ posé et arrivée feutrée, sans rebond.
    static func open(light: Bool) -> Animation {
        light
            ? .timingCurve(0.22, 0.85, 0.32, 1, duration: 0.16)
            : .timingCurve(0.45, 0.05, 0.2, 1, duration: 0.46)
    }

    static let navigation = Animation.timingCurve(0.24, 0.82, 0.3, 1, duration: 0.28)

    static func modeTransition(forward: Bool) -> AnyTransition {
        let side: CGFloat = forward ? 1 : -1
        return .asymmetric(
            insertion: .offset(x: 14 * Motion.amplitude * side).combined(with: .opacity),
            removal: .offset(x: -8 * Motion.amplitude * side).combined(with: .opacity)
        )
    }

    /// Cascade posée : les lignes se découvrent doucement derrière le paravent.
    static func row(_ order: Int) -> Animation {
        .timingCurve(0.22, 0.82, 0.3, 1, duration: 0.4).delay(0.16 + Double(min(order, 12)) * 0.04)
    }

    static let close = Animation.easeIn(duration: 0.18)
    static var rowOffset: CGSize { CGSize(width: 0, height: 8 * Motion.amplitude) }
    static let rowScale: CGFloat = 1
}

// MARK: - Mouvement du panneau et effet d'ouverture

/// Le panneau entier : glissement doux de paravent (8 pt) à l'ouverture et retrait feutré au lancement.
struct LacquerPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        let k = Motion.amplitude * (light ? 0.4 : 1)
        content
            .opacity(closing ? 0.55 : 1)
            .scaleEffect(closing ? 1 - 0.01 * k : 1, anchor: .center)
            .animation(Motion.scaled(LacquerLook.close), value: closing)
            // Les deux vantaux du paravent s'écartent depuis le centre, le long du fil d'or.
            .mask {
                // Marge négative : le masque déborde pour ne jamais rogner l'ombre portée.
                Rectangle().padding(-60).scaleEffect(x: hidden && !light ? 0.06 : 1, y: 1, anchor: .center)
            }
            .offset(y: hidden ? -4 * k : 0)
            .opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture : un fil d'or kintsugi se soude sous la recherche (part du centre, s'étend vers les bords
/// avec une fine veine organique irrégulière, brille puis se pose à faible intensité).
struct LacquerOpening: View {
    struct Values {
        /// Extension symétrique depuis le centre (0 → 1).
        var span: CGFloat = 0
        /// Intensité lumineuse de la soudure (pic brillant puis pose douce).
        var glow: Double = 0
        /// Opacité globale du fil.
        var opacity: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        let t = 1 / Motion.speed
        let amp = Double(min(max(Motion.amplitude, 0.5), 1.3))
        let y = size.height > 72 ? 60.0 : max(size.height - 3.0, 2.0)
        let inset: CGFloat = size.width > 300 ? 18 : 10
        let lineWidth = max(size.width - 2 * inset, 40)
        let gold = tokens.accent
        let bright = tokens.accent2
        let showVein = AppSettings.shared.lacquerKintsugi

        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay(alignment: .topLeading) {
                    if value.opacity > 0.002 && value.span > 0.002 {
                        Canvas { ctx, canvasSize in
                            let midY = canvasSize.height / 2
                            let half = (canvasSize.width / 2) * value.span
                            let leftX = canvasSize.width / 2 - half
                            let rightX = canvasSize.width / 2 + half

                            // Fil principal sous la recherche : léger tracé organique si kintsugi est actif.
                            var seam = Path()
                            let steps = 48
                            for i in 0...steps {
                                let u = CGFloat(i) / CGFloat(steps)
                                let x = leftX + (rightX - leftX) * u
                                let globalU = x / max(canvasSize.width, 1)
                                let wave = showVein
                                    ? (sin(globalU * 19.0) * 0.55 + sin(globalU * 47.0 + 1.2) * 0.25)
                                      * (1 - abs(globalU - 0.5) * 1.6).clamped(to: 0...1)
                                    : 0
                                let pt = CGPoint(x: x, y: midY + wave)
                                if i == 0 { seam.move(to: pt) } else { seam.addLine(to: pt) }
                            }

                            let gradient = GraphicsContext.Shading.linearGradient(
                                Gradient(stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: gold.opacity(0.65), location: 0.16),
                                    .init(color: bright, location: 0.5),
                                    .init(color: gold.opacity(0.65), location: 0.84),
                                    .init(color: .clear, location: 1.0),
                                ]),
                                startPoint: CGPoint(x: leftX, y: midY),
                                endPoint: CGPoint(x: rightX, y: midY)
                            )

                            // Halo chaud au moment de la soudure.
                            if value.glow > 0.02 {
                                ctx.drawLayer { layer in
                                    layer.addFilter(.blur(radius: 3.5 * CGFloat(amp)))
                                    layer.opacity = value.glow * 0.72 * value.opacity
                                    layer.stroke(seam, with: gradient, style: StrokeStyle(lineWidth: 3.2, lineCap: .round))
                                }
                            }

                            // Fil d'or fin soudé.
                            ctx.opacity = value.opacity
                            ctx.stroke(seam, with: gradient, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))

                            // Fine veine secondaire qui s'échappe brièvement vers la droite du centre.
                            if showVein && value.span > 0.35 {
                                let branchT = ((value.span - 0.35) / 0.65).clamped(to: 0...1)
                                let bx0 = canvasSize.width * 0.64
                                var branch = Path()
                                branch.move(to: CGPoint(x: bx0, y: midY + 0.3))
                                branch.addQuadCurve(
                                    to: CGPoint(x: bx0 + 22 * branchT, y: midY + 7.5 * branchT),
                                    control: CGPoint(x: bx0 + 10 * branchT, y: midY + 2.0 * branchT)
                                )
                                ctx.opacity = value.opacity * Double(branchT) * 0.55
                                ctx.stroke(
                                    branch,
                                    with: .linearGradient(
                                        Gradient(colors: [bright.opacity(0.85), gold.opacity(0.4), .clear]),
                                        startPoint: CGPoint(x: bx0, y: midY),
                                        endPoint: CGPoint(x: bx0 + 22 * branchT, y: midY + 7.5 * branchT)
                                    ),
                                    style: StrokeStyle(lineWidth: 0.85, lineCap: .round)
                                )
                            }
                        }
                        .frame(width: lineWidth, height: 22)
                        .offset(x: inset, y: y - 11)
                    }
                }
            } keyframes: { _ in
                KeyframeTrack(\.span) {
                    LinearKeyframe(0, duration: 0.03 * t)
                    CubicKeyframe(1.0, duration: 0.34 * t)
                    LinearKeyframe(1.0, duration: 0.38 * t)
                }
                KeyframeTrack(\.glow) {
                    LinearKeyframe(0, duration: 0.03 * t)
                    CubicKeyframe(1.0, duration: 0.24 * t)
                    CubicKeyframe(0.28, duration: 0.24 * t)
                    CubicKeyframe(0.0, duration: 0.24 * t)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0.95, duration: 0.04 * t)
                    LinearKeyframe(1.0, duration: 0.32 * t)
                    CubicKeyframe(0.32, duration: 0.22 * t)
                    CubicKeyframe(0.0, duration: 0.17 * t)
                }
            }
            .allowsHitTesting(false)
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

// MARK: - Matière laque & veine kintsugi (calculées une fois et mises en cache)

/// Textures déterministes calculées une seule fois en bitmap Retina : grain satiné de laque polie,
/// grain minéral de porcelaine mate et veine d'or kintsugi discrète dans le coin inférieur droit.
private enum LacquerTextures {
    static let kintsugiVein: NSImage = makeKintsugiVein()

    /// Urushi poli au charbon (reliefs dorés chauds) ou porcelaine mate (creux minéraux).
    static func grain(dark: Bool) -> NSImage {
        Grain.tile(dark
            ? Grain.Spec(amount: 0.05, light: .init(r: 1.0, g: 0.86, b: 0.62), lightShare: 0.75, specks: 0.002,
                         seed: 0x3F82_D109_A6C4_7E5B)
            : Grain.Spec(amount: 0.045, shadow: .init(r: 0.22, g: 0.18, b: 0.14), lightShare: 0.5, specks: 0.005,
                         seed: 0x9C41_8B23_E5D0_4A17))
    }

    /// Fine veine kintsugi organique, posée dans le coin inférieur droit du panneau (loin des titres et icônes).
    /// Courbe fluide finement subdivisée avec micro-tremblement céramique, épaississement naturel aux jonctions
    /// et poudre d'or maki-e diffuse. Image gabarit (template) teintée ensuite en or par SwiftUI.
    private static func makeKintsugiVein() -> NSImage {
        let w = 640, h = 320, scale = 2
        let image = bitmapImage(width: w, height: h, scale: scale) { ctx in
            ctx.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
            // Repère SwiftUI (y vers le bas).
            ctx.translateBy(x: 0, y: CGFloat(h))
            ctx.scaleBy(x: 1, y: -1)
            ctx.setAllowsAntialiasing(true)
            ctx.setShouldAntialias(true)
            ctx.setLineCap(.round)
            ctx.setLineJoin(.round)

            /// Échantillonne une courbe cubique de Bézier avec un léger micro-tremblement organique de fracture.
            func sampleCrack(
                p0: CGPoint, c1: CGPoint, c2: CGPoint, p3: CGPoint,
                steps: Int, wStart: CGFloat, wEnd: CGFloat, aStart: CGFloat, aEnd: CGFloat,
                jitter: CGFloat, seed: UInt64
            ) -> [(CGPoint, CGFloat, CGFloat)] {
                var result: [(CGPoint, CGFloat, CGFloat)] = []
                var s = seed
                for i in 0...steps {
                    let t = CGFloat(i) / CGFloat(steps)
                    let u = 1 - t
                    let bx = u * u * u * p0.x + 3 * u * u * t * c1.x + 3 * u * t * t * c2.x + t * t * t * p3.x
                    let by = u * u * u * p0.y + 3 * u * u * t * c1.y + 3 * u * t * t * c2.y + t * t * t * p3.y
                    // Micro-tremblement continu aux extrémités nulles pour garder la continuité aux jonctions.
                    let env = sin(t * .pi)
                    s = s &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                    let n1 = (CGFloat((s >> 24) & 0xFF) / 255.0 - 0.5) * 2
                    let wave = sin(t * 23.0 + CGFloat(seed % 7)) * 0.65 + sin(t * 53.0) * 0.35
                    let dx = (wave * 0.7 + n1 * 0.3) * jitter * env
                    let dy = (cos(t * 19.0 + CGFloat(seed % 11)) * 0.65 - n1 * 0.3) * jitter * env
                    let width = wStart + (wEnd - wStart) * t + abs(wave) * 0.14 * env
                    let alpha = aStart + (aEnd - aStart) * t
                    result.append((CGPoint(x: bx + dx, y: by + dy), width, alpha))
                }
                return result
            }

            let mainCrack = sampleCrack(
                p0: CGPoint(x: 644, y: 184),
                c1: CGPoint(x: 592, y: 196),
                c2: CGPoint(x: 544, y: 248),
                p3: CGPoint(x: 472, y: 324),
                steps: 44, wStart: 1.55, wEnd: 0.65, aStart: 0.94, aEnd: 0.44,
                jitter: 2.6, seed: 0x1A2B_3C4D
            )
            let junctionA = mainCrack[16].0
            let branchA = sampleCrack(
                p0: junctionA,
                c1: CGPoint(x: junctionA.x + 14, y: junctionA.y + 24),
                c2: CGPoint(x: junctionA.x + 28, y: junctionA.y + 58),
                p3: CGPoint(x: 616, y: 324),
                steps: 24, wStart: 0.95, wEnd: 0.38, aStart: 0.78, aEnd: 0.22,
                jitter: 1.8, seed: 0x5E6F_7A8B
            )
            let junctionB = mainCrack[25].0
            let branchB = sampleCrack(
                p0: junctionB,
                c1: CGPoint(x: junctionB.x - 24, y: junctionB.y - 4),
                c2: CGPoint(x: junctionB.x - 48, y: junctionB.y + 6),
                p3: CGPoint(x: junctionB.x - 74, y: junctionB.y + 2),
                steps: 18, wStart: 0.72, wEnd: 0.22, aStart: 0.58, aEnd: 0.04,
                jitter: 1.4, seed: 0x9C0D_1E2F
            )

            func strokeVein(_ pts: [(CGPoint, CGFloat, CGFloat)]) {
                guard pts.count >= 2 else { return }
                // Passe 1 : poudre d'or maki-e diffuse autour du trait.
                for i in 0..<(pts.count - 1) {
                    let (p0, w0, a0) = pts[i]
                    let (p1, w1, a1) = pts[i + 1]
                    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: (a0 + a1) * 0.10))
                    ctx.setLineWidth((w0 + w1) * 1.6)
                    ctx.beginPath()
                    ctx.move(to: p0)
                    ctx.addLine(to: p1)
                    ctx.strokePath()
                }
                // Passe 2 : filet d'or net à épaisseur variable.
                for i in 0..<(pts.count - 1) {
                    let (p0, w0, a0) = pts[i]
                    let (p1, w1, a1) = pts[i + 1]
                    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: (a0 + a1) * 0.5))
                    ctx.setLineWidth((w0 + w1) * 0.5)
                    ctx.beginPath()
                    ctx.move(to: p0)
                    ctx.addLine(to: p1)
                    ctx.strokePath()
                }
            }

            strokeVein(mainCrack)
            strokeVein(branchA)
            strokeVein(branchB)

            // Légère goutte d'or aux jonctions (là où la laque urushi s'accumule avant le saupoudrage).
            for pt in [junctionA, junctionB] {
                ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.55))
                ctx.fillEllipse(in: CGRect(x: pt.x - 1.35, y: pt.y - 1.35, width: 2.7, height: 2.7))
            }

            // Minuscules poussières d'or (nashiji) éparses près de la soudure.
            var seed: UInt64 = 0x7A21_C904_3E85_B11D
            for i in 0..<28 {
                seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
                let anchor = mainCrack[(i * 3) % (mainCrack.count - 1)].0
                let dx = (Double((seed >> 16) & 0xFF) / 255.0 - 0.5) * 38.0
                let dy = (Double((seed >> 24) & 0xFF) / 255.0 - 0.5) * 30.0
                let r = 0.4 + Double((seed >> 32) & 0xFF) / 255.0 * 0.65
                let a = 0.16 + Double((seed >> 40) & 0xFF) / 255.0 * 0.30
                ctx.setFillColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: a))
                ctx.fillEllipse(in: CGRect(x: anchor.x + dx - r, y: anchor.y + dy - r, width: r * 2, height: r * 2))
            }
        }
        image.isTemplate = true
        return image
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

// MARK: - Décor du cadre, du panneau, de la sélection, des séparateurs et des pastilles

/// Cadre extérieur en laque urushi / porcelaine / cinabre : grain satiné, lustre discret en haut,
/// ombre intérieure veloutée en bas, et bordure 1 pt en dégradé doré (30 % en haut → 8 % en bas).
struct LacquerSurface: View {
    let decor: LacquerDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            // Grain satiné imperceptible qui donne de la matière à la laque ou à la porcelaine mate.
            Rectangle()
                .fill(ImagePaint(image: Image(nsImage: LacquerTextures.grain(dark: decor.dark))))
                .opacity(decor.grain ? 1 : 0)
                .clipShape(shape)

            // Lustre satiné à peine visible en haut du panneau, profondeur veloutée vers le bas.
            if decor.sheen {
                let sheenTint = decor.mode == .cinnabar ? Color(hex: "#F2B688") : (decor.dark ? decor.goldBright : Color.white)
                shape.fill(
                    LinearGradient(
                        stops: [
                            .init(color: sheenTint.opacity(decor.dark ? 0.07 : 0.40), location: 0.0),
                            .init(color: Color.white.opacity(decor.dark ? 0.02 : 0.14), location: 0.16),
                            .init(color: .clear, location: 0.36),
                            .init(color: Color.black.opacity(decor.dark ? 0.22 : 0.05), location: 1.0),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Reflet courbe très doux en haut au centre, comme une pièce de laque sous une lumière rasante.
                shape.fill(
                    RadialGradient(
                        colors: [
                            sheenTint.opacity(decor.dark ? 0.06 : 0.22),
                            .clear,
                        ],
                        center: UnitPoint(x: 0.5, y: -0.05),
                        startRadius: 10,
                        endRadius: 340
                    )
                )
            }

            // Bordure 1 pt en dégradé doré : 30 % en haut → 8 % en bas (légèrement plus soutenue sur porcelaine claire).
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: decor.goldBright.opacity(decor.dark ? 0.30 : 0.46), location: 0.0),
                        .init(color: decor.accent.opacity(decor.dark ? 0.18 : 0.26), location: 0.42),
                        .init(color: decor.accent.opacity(decor.dark ? 0.08 : 0.14), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        }
        .allowsHitTesting(false)
    }
}

/// Panneau intérieur en retrait : plateau de laque satinée (ou porcelaine mate), lustre doux en haut,
/// veine kintsugi discrète dans le coin inférieur droit et filet intérieur doré très fin.
struct LacquerPane: View {
    let decor: LacquerDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            Rectangle()
                .fill(ImagePaint(image: Image(nsImage: LacquerTextures.grain(dark: decor.dark))))
                .opacity(decor.grain ? 1 : 0)

            if decor.sheen {
                LinearGradient(
                    stops: [
                        .init(color: (decor.dark ? decor.goldBright : Color.white).opacity(decor.dark ? 0.045 : 0.45), location: 0.0),
                        .init(color: .clear, location: 0.24),
                        .init(color: .clear, location: 0.78),
                        .init(color: Color.black.opacity(decor.dark ? 0.18 : 0.035), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }

            // Veine d'or kintsugi en filigrane dans le coin inférieur droit, hors de la zone de lecture.
            if decor.kintsugi {
                GeometryReader { geo in
                    if geo.size.width > 180 && geo.size.height > 80 {
                        Image(nsImage: LacquerTextures.kintsugiVein)
                            .renderingMode(.template)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [decor.goldDeep, decor.accent, decor.goldBright],
                                    startPoint: .bottomLeading,
                                    endPoint: .topTrailing
                                )
                            )
                            .opacity(decor.dark ? 0.24 : 0.30)
                    }
                }
            }

            // Filet intérieur fin qui sertit le plateau dans le cadre, avec léger éclat doré au centre en haut.
            shape.strokeBorder(
                LinearGradient(
                    stops: [
                        .init(color: decor.accent.opacity(decor.dark ? 0.20 : 0.28), location: 0.0),
                        .init(color: decor.accent.opacity(decor.dark ? 0.07 : 0.12), location: 0.45),
                        .init(color: Color.black.opacity(decor.dark ? 0.38 : 0.08), location: 1.0),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 0.75
            )
            VStack(spacing: 0) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: 0.0),
                                .init(color: decor.accent.opacity(decor.dark ? 0.16 : 0.18), location: 0.22),
                                .init(color: (decor.dark ? decor.goldBright : decor.accent).opacity(decor.dark ? 0.32 : 0.34), location: 0.5),
                                .init(color: decor.accent.opacity(decor.dark ? 0.16 : 0.18), location: 0.78),
                                .init(color: .clear, location: 1.0),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
                Spacer(minLength: 0)
            }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

/// Par-dessus le surlignage de la ligne choisie : légère chaleur satinée et filet doré de 1,5 pt
/// en bas, plus lumineux au centre (dégradé transparent → or → transparent).
struct LacquerSelection: View {
    let decor: LacquerDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        GeometryReader { geo in
            let tiny = geo.size.height < 20
            let barHeight: CGFloat = tiny ? 1.0 : 1.5
            let insetH: CGFloat = tiny ? 3 : 8

            ZStack {
                // Légère lueur satinée en haut de la ligne choisie.
                shape.fill(
                    LinearGradient(
                        colors: [
                            (decor.dark ? decor.goldBright : Color.white).opacity(decor.dark ? 0.06 : 0.32),
                            .clear,
                        ],
                        startPoint: .top,
                        endPoint: .center
                    )
                )

                // Filet très discret autour de la sélection pour ancrer la matière.
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            decor.accent.opacity(decor.dark ? 0.14 : 0.18),
                            decor.accent.opacity(decor.dark ? 0.04 : 0.06),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 0.5
                )

                // Soulignement doré de 1,5 pt plus lumineux au centre (transparent → or → transparent).
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Capsule()
                        .fill(
                            LinearGradient(
                                stops: [
                                    .init(color: .clear, location: 0.0),
                                    .init(color: decor.accent.opacity(decor.dark ? 0.45 : 0.48), location: 0.15),
                                    .init(color: decor.dark ? decor.goldBright : Color(hex: "#B5852A"), location: 0.50),
                                    .init(color: decor.accent.opacity(decor.dark ? 0.45 : 0.48), location: 0.85),
                                    .init(color: .clear, location: 1.0),
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(height: barHeight)
                        .shadow(color: decor.accent.opacity(decor.dark ? 0.55 : 0.22), radius: tiny ? 1.5 : (decor.dark ? 3.5 : 1.5), y: 0)
                        .padding(.horizontal, insetH)
                        .padding(.bottom, 0.5)
                }
            }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

/// Séparateur en filet d'or fondu aux extrémités.
/// En-tête et pied de page : le plateau intérieur (`LacquerPane`) porte déjà son filet doré,
/// on évite ainsi tout double trait ; seuls les séparateurs internes (`.plain` ou verticaux) se dessinent.
struct LacquerDivider: View {
    let decor: LacquerDecor
    let vertical: Bool
    let role: StyleDivider.Role

    var body: some View {
        if vertical || role == .plain {
            let peak: Double = decor.dark ? 0.24 : 0.28
            let edge: Double = peak * 0.22
            let gradient = LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: decor.accent.opacity(edge), location: 0.14),
                    .init(color: decor.accent.opacity(peak), location: 0.5),
                    .init(color: decor.accent.opacity(edge), location: 0.86),
                    .init(color: .clear, location: 1.0),
                ],
                startPoint: vertical ? .top : .leading,
                endPoint: vertical ? .bottom : .trailing
            )
            Rectangle()
                .fill(gradient)
                .padding(vertical ? .vertical : .horizontal, 16)
                .allowsHitTesting(false)
        }
    }
}

/// Pastille d'un symbole : médaillon de laque cerclé d'or (plus lumineux lorsqu'il est choisi).
struct LacquerTile: View {
    let decor: LacquerDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let details = side >= 14
            let strokeWidth: CGFloat = details ? (selected ? 1.2 : 0.95) : 0.65

            ZStack {
                // Disque de laque ou de porcelaine mate.
                Circle()
                    .fill(selected ? decor.tileSelectedFill : decor.tileRestFill)
                    .overlay {
                        Circle().fill(
                            LinearGradient(
                                colors: [
                                    (decor.dark ? decor.goldBright : Color.white).opacity(selected ? 0.18 : 0.08),
                                    .clear,
                                    Color.black.opacity(decor.dark ? 0.28 : 0.05),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                    // Cercle d'or fin autour de la pastille.
                    .overlay {
                        Circle().strokeBorder(
                            LinearGradient(
                                colors: [
                                    (selected ? decor.goldBright : decor.accent).opacity(selected ? 0.98 : 0.64),
                                    decor.accent.opacity(selected ? 0.78 : 0.38),
                                    decor.goldDeep.opacity(selected ? 0.62 : 0.26),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: strokeWidth
                        )
                    }
                    .shadow(color: selected && decor.dark ? decor.accent.opacity(0.32) : .clear, radius: 3)

                if details {
                    Image(systemName: name)
                        .font(.system(size: side * 0.44, weight: selected ? .medium : .regular))
                        .foregroundStyle(selected ? (decor.dark ? decor.goldBright : decor.goldDeep) : decor.accent)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .padding(1)
    }
}

// MARK: - Logo kintsugi

/// Anneau du logo : ivoire (ou encre charbon en Porcelaine) avec une fine fracture réparée à l'or (kintsugi).
struct LacquerMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        let kintsugi = AppSettings.shared.lacquerKintsugi
        let dark = LacquerLook.isDark
        let goldBright = dark ? Color(hex: "#F3D68D") : Color(hex: "#CFA652")

        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: side / 2, y: side / 2)
            let ringR = side * MarkGeometry.ringRadius
            // Angle de la réparation kintsugi (bas-gauche de l'anneau, ≈ 140°).
            let seamFraction: CGFloat = 0.52
            let seamAngle = (MarkGeometry.startDegrees + MarkGeometry.spanDegrees * Double(seamFraction)) * .pi / 180.0

            ZStack {
                if kintsugi && side >= 12 && progress > seamFraction + 0.04 {
                    // Deux segments d'anneau séparés par une fine fente, ressoudés à l'or kintsugi.
                    MarkRing().trim(from: 0, to: seamFraction - 0.024)
                        .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
                    MarkRing().trim(from: seamFraction + 0.024, to: progress)
                        .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round))

                    // Soudure kintsugi en diagonale qui comble nettement la fente.
                    Path { p in
                        let rInner = ringR - line * 0.64
                        let rOuter = ringR + line * 0.64
                        let a0 = seamAngle - 0.16
                        let a1 = seamAngle + 0.16
                        p.move(to: CGPoint(x: center.x + cos(a0) * rInner, y: center.y + sin(a0) * rInner))
                        p.addLine(to: CGPoint(x: center.x + cos(a1) * rOuter, y: center.y + sin(a1) * rOuter))
                    }
                    .stroke(
                        LinearGradient(colors: [dot, goldBright, dot], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: max(1.25, line * 0.48), lineCap: .round)
                    )
                    .shadow(color: dark ? dot.opacity(0.65) : .clear, radius: max(1, line * 0.4))
                } else {
                    MarkRing().trim(from: 0, to: progress)
                        .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .round))
                }
            }
            .frame(width: side, height: side)
        }
    }
}

/// Point du logo : perle d'or poli (reflet maki-e en haut à gauche, lueur douce en sombre).
struct LacquerMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        let dark = LacquerLook.isDark
        let bright = dark ? Color(hex: "#F6DDA0") : Color(hex: "#DCBA6D")
        let deep = dark ? Color(hex: "#8E6C2A") : Color(hex: "#7D5B1C")
        let diameter = max(2 * radius, 0.5)

        Circle()
            .fill(
                RadialGradient(
                    colors: [bright, dot, deep],
                    center: UnitPoint(x: 0.34, y: 0.32),
                    startRadius: 0,
                    endRadius: max(radius * 1.15, 1)
                )
            )
            .frame(width: diameter, height: diameter)
            .shadow(color: dark ? dot.opacity(0.45) : .clear, radius: max(radius * 0.7, 1.5))
    }
}

// MARK: - Réglages › Apparence

/// Réglages › Apparence, quand la peau Laque est choisie.
struct LacquerSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Variante", selection: $settings.lacquerMode) {
                ForEach(LacquerMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Veine d'or kintsugi", isOn: $settings.lacquerKintsugi)
            Toggle("Lustre satiné", isOn: $settings.lacquerSheen)
            Toggle("Grain de la laque", isOn: $settings.lacquerGrain)
        } header: {
            Text("Laque")
        } footer: {
            Text("Urushi (ébène satiné), Porcelaine (mate et or brossé) ou Cinabre (brun rouge profond). Auto suit l'apparence du Mac.")
        }
    }
}
