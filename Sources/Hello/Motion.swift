import AppKit
import SwiftUI

/// Signature de mouvement d'un style : comment le panneau s'ouvre, comment les lignes arrivent,
/// comment on passe d'un écran à l'autre et comment il s'efface quand on lance une app.
enum RevealStyle {
    /// Verre : le panneau naît d'une goutte sous la barre de recherche qui gonfle jusqu'à la fenêtre, flou qui se met au point.
    case glass
    /// Atelier (Material 3 Expressive) : le panneau se déploie depuis la barre de recherche, lignes en vagues.
    case unfold
    /// Atelier Glyphe : le panneau se pose sur un ressort, une onde de points part du logo et traverse le panneau.
    case wave
    /// Phosphore : allumage cathodique (une ligne qui s'ouvre), scintillement, lignes « tapées » une à une.
    case crt
    /// Papier : la feuille se déplie vers l'avant, lignes qui glissent comme de l'encre.
    case page
    /// Néo-brutal : le panneau tombe et rebondit sur son ombre, lignes qui sautent en place.
    case slam

    /// Ce qui caractérise le mouvement du style (affiché dans Réglages › Animations).
    var summary: String {
        switch self {
        case .glass: "le panneau naît d'une goutte d'eau sous la barre de recherche, qui gonfle, s'étale jusqu'à la "
            + "fenêtre et ondule en se posant. Le flou se met au point et un reflet lumineux fait le tour du bord."
        case .unfold: "ressorts Material 3 Expressive. Le panneau se déploie depuis la barre de recherche, les résultats "
            + "arrivent en vagues et les pastilles changent de forme quand on les sélectionne."
        case .wave: "trois ressorts, pas de courbe fixe : ça arrive, ça se pose. Les résultats montent en cascade serrée "
            + "et les coins des pastilles s'arrondissent quand on les choisit."
        case .crt: "allumage cathodique avec scintillement, résultats affichés ligne par ligne et curseur qui clignote. "
            + "Au lancement d'une app, l'écran s'éteint en trait."
        case .page: "la feuille se déplie vers l'avant, les résultats glissent comme de l'encre et le marque-page suit la sélection."
        case .slam: "le panneau tombe et rebondit sur son ombre, les résultats sautent en place. Au lancement, il s'enfonce "
            + "comme un bouton qu'on presse."
        }
    }

    /// L'effet joué à chaque ouverture (Réglages › Animations).
    var effect: String {
        switch self {
        case .glass: "un reflet multicolore fait le tour du bord."
        case .unfold: "un anneau de focus se dessine autour de la barre de recherche, dans un halo du second accent."
        case .wave: "une onde de points part du logo, traverse le panneau dans la couleur d'accent et s'éteint."
        case .crt: "le faisceau balaie l'écran une fois, de haut en bas."
        case .page: "un trait d'encre se trace sous la recherche, puis sèche et s'efface."
        case .slam: "une ombre de la couleur de sélection claque sous le panneau, puis rentre sous l'ombre noire."
        }
    }

    /// Ouverture du panneau. `light` : réouverture rapide, version écourtée.
    func open(light: Bool) -> Animation {
        switch self {
        case .glass: light ? .snappy(duration: 0.14) : .spring(response: 0.46, dampingFraction: 0.7)
        case .unfold: light ? .spring(response: 0.22, dampingFraction: 0.86) : .spring(response: 0.44, dampingFraction: 0.72)
        case .wave: light ? .spring(response: 0.22, dampingFraction: 0.9) : .spring(response: 0.46, dampingFraction: 0.8)
        case .crt: light ? .easeOut(duration: 0.1) : .timingCurve(0.2, 0.9, 0.3, 1, duration: 0.34)
        case .page: light ? .easeOut(duration: 0.14) : .spring(response: 0.48, dampingFraction: 0.84)
        case .slam: light ? .spring(response: 0.2, dampingFraction: 0.75) : .spring(response: 0.36, dampingFraction: 0.5)
        }
    }

    /// Changement d'écran (applications, presse-papiers, retour…).
    var navigation: Animation {
        switch self {
        case .glass: .snappy(duration: 0.24)
        case .unfold: .spring(response: 0.38, dampingFraction: 0.86)
        case .wave: .spring(response: 0.36, dampingFraction: 0.82)
        case .crt: .linear(duration: 0.06)
        case .page: .easeInOut(duration: 0.26)
        case .slam: .spring(response: 0.3, dampingFraction: 0.62)
        }
    }

    func modeTransition(forward: Bool) -> AnyTransition {
        let k = Motion.amplitude
        let side: CGFloat = forward ? 1 : -1
        switch self {
        case .glass:
            return .asymmetric(insertion: .offset(x: 36 * k * side).combined(with: .opacity), removal: .opacity)
        case .unfold:
            // « Axe partagé » de Material : l'ancien écran part d'un côté pendant que le nouveau arrive de l'autre.
            return .asymmetric(insertion: .offset(x: 30 * k * side).combined(with: .opacity).combined(with: .scale(scale: 0.98)),
                               removal: .offset(x: -30 * k * side).combined(with: .opacity))
        case .wave:
            return .asymmetric(insertion: .offset(x: 22 * k * side).combined(with: .opacity), removal: .opacity)
        case .crt:
            return .opacity
        case .page:
            return .asymmetric(insertion: .offset(y: 8 * k).combined(with: .opacity), removal: .opacity)
        case .slam:
            return .asymmetric(insertion: .offset(x: 60 * k * side).combined(with: .opacity), removal: .opacity)
        }
    }

    /// Arrivée d'une ligne (rang `order` dans la cascade).
    func row(_ order: Int) -> Animation {
        let n = Double(min(order, 12))
        return switch self {
        case .glass: .spring(response: 0.28, dampingFraction: 0.8).delay(0.04 + n * 0.018)
        case .unfold: .spring(response: 0.5, dampingFraction: 0.72).delay(0.08 + n * 0.035)
        // Décalage de 34 ms d'un élément au suivant, comme les planches de l'artifact.
        case .wave: .spring(response: 0.44, dampingFraction: 0.8).delay(Self.waveDelay(order))
        // Une ligne après l'autre, sans fondu : comme un terminal qui affiche sa sortie.
        case .crt: .linear(duration: 0.001).delay(0.2 + Double(min(order, 14)) * 0.045)
        case .page: .easeOut(duration: 0.34).delay(0.1 + n * 0.03)
        case .slam: .spring(response: 0.32, dampingFraction: 0.5).delay(0.14 + n * 0.03)
        }
    }

    /// Glyphe : départ d'une ligne dans la cascade (le titre se décode au même moment).
    static func waveDelay(_ order: Int) -> Double { 0.06 + Double(min(order, 12)) * 0.034 }

    /// Effacement quand on lance une app (en même temps que le fondu de la fenêtre, ≈0,2 s).
    var close: Animation {
        switch self {
        case .glass: .easeOut(duration: 0.22)
        case .unfold: .spring(response: 0.24, dampingFraction: 0.6)
        case .wave: .spring(response: 0.2, dampingFraction: 0.9)
        case .crt: .easeIn(duration: 0.16)
        case .page: .easeIn(duration: 0.2)
        case .slam: .spring(response: 0.16, dampingFraction: 0.7)
        }
    }
}

/// Réglages globaux du mouvement (Réglages › Animations).
enum Motion {
    static var enabled: Bool {
        AppSettings.shared.animations && !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }
    static var amplitude: CGFloat { AppSettings.shared.motionIntensity.amplitude }
    /// Glyphe : textes et icônes se décodent en ASCII en apparaissant (Réglages › Animations).
    static var decodes: Bool { enabled && AppSettings.shared.asciiDecode && StyleTokens.current.asciiReveal }
    static var speed: Double {
        let value = AppSettings.shared.animationSpeed
        return value.isFinite ? min(max(value, 0.5), 2) : 1
    }

    /// Animation à la vitesse réglée, ou nil si les animations sont coupées.
    static func scaled(_ animation: Animation?) -> Animation? {
        guard enabled, let animation else { return nil }
        return animation.speed(speed)
    }
}

/// Le panneau entier : ouverture (selon `shown`) et effacement au lancement d'une app (selon `closing`).
struct PanelMotion: ViewModifier {
    let reveal: RevealStyle
    let shown: Bool
    var light = false
    var closing = false
    var revealID = 0

    func body(content: Content) -> some View {
        let k = Motion.amplitude * (light ? 0.35 : 1)
        let hidden = !shown && Motion.enabled
        let closing = closing && Motion.enabled
        let close = Motion.scaled(reveal.close)
        switch reveal {
        case .glass:
            // La goutte grossit avec le ressort d'ouverture ; elle doit être visible tout de suite, d'où un fondu
            // à part, bien plus court. Réouverture rapide : pas de goutte, juste un petit ressort.
            content
                .mask(DropletShape(progress: hidden && !light ? 0 : 1, cornerRadius: PanelLayout.radius))
                .scaleEffect(closing ? 0.985 : 1)
                .animation(close, value: closing)
                .scaleEffect(hidden ? 1 - 0.12 * k : 1, anchor: UnitPoint(x: 0.5, y: 0.07))
                .animation(shown ? Motion.scaled(.easeOut(duration: 0.1)) : nil) { $0.opacity(hidden ? 0 : 1) }
                .modifier(LiquidWobble(trigger: revealID, active: !light))
        case .unfold:
            content
                .scaleEffect(closing ? 1 + 0.02 * k : 1)
                .animation(close, value: closing)
                .scaleEffect(x: hidden ? 1 - 0.05 * k : 1, y: hidden ? max(0.3, 1 - 0.4 * k) : 1, anchor: .top)
                .offset(y: hidden ? -10 * k : 0)
                .opacity(hidden ? 0 : 1)
        case .wave:
            // Le panneau part d'un peu plus petit et se pose ; au lancement, il recule d'un cran.
            content
                .scaleEffect(closing ? 1 - 0.025 * k : 1)
                .animation(close, value: closing)
                .scaleEffect(hidden ? 1 - 0.03 * k : 1, anchor: .top)
                .offset(y: hidden ? 6 * k : 0)
                .opacity(hidden ? 0 : 1)
        case .crt:
            // Allumage : un trait lumineux qui s'ouvre en écran. Extinction : l'écran s'écrase en trait.
            content
                .scaleEffect(x: closing ? 0.6 : 1, y: closing ? 0.006 : 1)
                .brightness(closing ? 0.7 : 0)
                .animation(close, value: closing)
                .scaleEffect(x: hidden ? 1 - 0.08 * min(k, 1) : 1, y: hidden ? max(0.01, 1 - min(k, 1)) : 1)
                .brightness(hidden ? 0.6 : 0)
                .opacity(hidden ? 0 : 1)
                .modifier(CRTFlicker(trigger: revealID, active: !light))
        case .page:
            content
                .rotation3DEffect(.degrees(closing ? 10 * k : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
                .offset(y: closing ? -8 * k : 0)
                .animation(close, value: closing)
                .rotation3DEffect(.degrees(hidden ? -24 * k : 0), axis: (x: 1, y: 0, z: 0), anchor: .top, perspective: 0.5)
                .offset(y: hidden ? -6 * k : 0)
                .opacity(hidden ? 0 : 1)
        case .slam:
            // Au lancement, le panneau « s'enfonce » sur son ombre pleine, comme un bouton qu'on presse.
            content
                .offset(x: closing ? 6 : 0, y: closing ? 6 : 0)
                .animation(close, value: closing)
                .offset(y: hidden ? -48 * k : 0)
                .scaleEffect(hidden ? 1 + 0.04 * k : 1)
                .rotationEffect(.degrees(hidden ? -1.5 * k : 0))
                .opacity(hidden ? 0 : 1)
        }
    }
}

/// Arrivée en cascade des lignes, selon le style.
struct RevealItem: ViewModifier {
    let order: Int
    let shown: Bool
    var light = false
    /// Style dont on joue le mouvement (par défaut celui du panneau ; les aperçus des réglages passent le leur).
    var reveal: RevealStyle? = nil

    func body(content: Content) -> some View {
        let reveal = reveal ?? AppSettings.shared.panelStyle.reveal
        let animate = Motion.enabled && AppSettings.shared.cascadeRows && !light
        let hidden = !shown && animate
        let k = Motion.amplitude
        let offset: CGSize = switch reveal {
        case .glass: CGSize(width: 0, height: 10 * k)
        case .unfold: CGSize(width: 0, height: 18 * k)
        case .wave: CGSize(width: 0, height: 14 * k)
        case .crt: .zero
        case .page: CGSize(width: -10 * k, height: 0)
        case .slam: CGSize(width: 0, height: 14 * k)
        }
        let scale: CGFloat = switch reveal {
        case .unfold: 1 - 0.06 * k
        case .wave: 1 - 0.015 * k
        case .slam: 1 - 0.15 * k
        default: 1
        }
        content
            .opacity(hidden ? 0 : 1)
            .scaleEffect(hidden ? scale : 1, anchor: .top)
            .offset(hidden ? offset : .zero)
            .animation(shown && animate ? Motion.scaled(reveal.row(order)) : nil, value: shown)
    }
}

/// Scintillement d'un tube cathodique juste après l'allumage.
struct CRTFlicker: ViewModifier {
    let trigger: Int
    let active: Bool

    func body(content: Content) -> some View {
        if active && Motion.enabled {
            let t = 1 / Motion.speed
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, value in
                view.opacity(value)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1, duration: 0.32 * t)
                    LinearKeyframe(0.55, duration: 0.03 * t)
                    LinearKeyframe(1, duration: 0.04 * t)
                    LinearKeyframe(0.8, duration: 0.03 * t)
                    LinearKeyframe(1, duration: 0.06 * t)
                }
            }
        } else {
            content
        }
    }
}

/// Curseur bloc qui clignote (Phosphore), devant la ligne sélectionnée.
struct BlinkingCursor: View {
    var height: CGFloat = 15

    var body: some View {
        if Motion.enabled {
            TimelineView(.periodic(from: .now, by: 0.53)) { context in
                Rectangle()
                    .frame(width: height * 0.55, height: height)
                    .opacity(Int(context.date.timeIntervalSinceReferenceDate / 0.53) % 2 == 0 ? 1 : 0)
            }
        } else {
            Rectangle().frame(width: height * 0.55, height: height)
        }
    }
}

// MARK: - Effets d'ouverture

/// Effet joué à chaque ouverture, propre au style (Réglages › Animations › « Effet d'ouverture »).
/// `pill` : la barre de recherche (Atelier) ; `underline` : la ligne sous le texte recherché (Papier) ;
/// `mark` : le centre du logo (Glyphe).
struct OpeningEffect: View {
    let style: PanelStyle
    let tokens: StyleTokens
    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let pill: CGRect
    let underline: CGRect
    let mark: CGPoint

    /// Le reflet multicolore du Verre.
    static let glassColors = [Color(red: 0.36, green: 0.30, blue: 0.98), Color(red: 0.93, green: 0.36, blue: 0.75),
                              Color(red: 1.00, green: 0.66, blue: 0.40), Color.white]

    var body: some View {
        if AppSettings.shared.haloSweep && Motion.enabled {
            switch style {
            case .glass:
                HaloSweep(trigger: trigger, size: size, radius: radius, colors: Self.glassColors)
            case .atelier:
                FocusRing(trigger: trigger, size: size, pill: pill, colors: (tokens.accent, tokens.accent2))
            case .glyph:
                DotWave(trigger: trigger, size: size, radius: radius, origin: mark, color: tokens.primaryKeyFill ?? tokens.accent)
            case .phosphor:
                ScanBeam(trigger: trigger, size: size, radius: radius, color: tokens.ink)
            case .paper:
                InkStroke(trigger: trigger, size: size, line: underline, color: tokens.accent)
            case .brutal:
                // Joué sous le panneau, avec l'ombre pleine (StampShadow).
                EmptyView()
            }
        }
    }
}

/// Verre : la goutte d'où naît le panneau. À 0, une petite goutte sous la barre de recherche ; elle s'étale
/// d'abord en largeur puis coule vers le bas (la hauteur suit le carré de la progression). À 1, la forme déborde
/// largement du panneau : le masque ne coupe plus rien, pas même l'ombre.
struct DropletShape: Shape {
    var progress: CGFloat
    let cornerRadius: CGFloat

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let bleed: CGFloat = 100
        let seed: CGFloat = 44
        let p = max(0, progress)
        let wide = p, tall = p * p
        let width = seed + (rect.width + 2 * bleed - seed) * wide
        let height = seed + (rect.height + 2 * bleed - seed) * tall
        let start = min(30, rect.height / 2) - seed / 2
        let top = start + (-bleed - start) * wide
        let radius = min(seed / 2 + (cornerRadius + bleed - seed / 2) * p, min(width, height) / 2)
        let frame = CGRect(x: rect.midX - width / 2, y: top, width: width, height: height)
        return RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: frame)
    }
}

/// Verre : la goutte se pose. Elle s'étire en hauteur en finissant de couler, s'étale en touchant sa place,
/// puis reprend sa forme en une oscillation amortie. Le volume est conservé (largeur × hauteur constant)
/// et l'ancre reste en haut : la barre de recherche ne bouge pas verticalement, l'œil n'a rien à rattraper.
struct LiquidWobble: ViewModifier {
    let trigger: Int
    let active: Bool

    func body(content: Content) -> some View {
        if active && Motion.enabled {
            let t = 1 / Motion.speed
            let k = 0.018 * Motion.amplitude
            // < 0 : étiré en hauteur ; > 0 : étalé en largeur.
            content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, squash in
                let x = 1 + k * squash
                view.scaleEffect(x: x, y: 1 / x, anchor: .top)
            } keyframes: { _ in
                // Calé sur le ressort d'ouverture : la goutte atteint la taille de la fenêtre vers 0,3 s.
                LinearKeyframe(0, duration: 0.12 * t)
                CubicKeyframe(-0.6, duration: 0.12 * t)
                CubicKeyframe(1, duration: 0.1 * t)
                SpringKeyframe(0, duration: 0.8 * t, spring: .init(response: 0.42, dampingRatio: 0.5))
            }
        } else {
            content
        }
    }
}

/// Atelier : un anneau de focus Material se dessine autour de la barre de recherche, dans un halo du second accent.
struct FocusRing: View {
    struct Values {
        var trim: CGFloat = 0
        var opacity: Double = 0
        var glow: CGFloat = 0
    }

    let trigger: Int
    let size: CGSize
    let pill: CGRect
    let colors: (Color, Color)

    var body: some View {
        let t = 1 / Motion.speed
        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay(alignment: .topLeading) {
                    if value.opacity > 0.001 {
                        ZStack {
                            Capsule()
                                .stroke(colors.1, lineWidth: 5)
                                .blur(radius: 7)
                                .scaleEffect(x: 1 + 0.015 * value.glow, y: 1 + 0.12 * value.glow)
                                .opacity(Double(1 - value.glow) * 0.9)
                            Capsule()
                                .trim(from: 0, to: value.trim)
                                .stroke(colors.0, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        }
                        .frame(width: pill.width, height: pill.height)
                        .offset(x: pill.minX, y: pill.minY)
                        .opacity(value.opacity)
                    }
                }
            } keyframes: { _ in
                KeyframeTrack(\.trim) {
                    LinearKeyframe(0, duration: 0.14 * t)
                    SpringKeyframe(1, duration: 0.55 * t, spring: .init(response: 0.5, dampingRatio: 0.9))
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.1 * t)
                    LinearKeyframe(1, duration: 0.7 * t)
                    CubicKeyframe(0, duration: 0.35 * t)
                }
                KeyframeTrack(\.glow) {
                    LinearKeyframe(0, duration: 0.3 * t)
                    CubicKeyframe(1, duration: 0.6 * t)
                }
            }
            .allowsHitTesting(false)
    }
}

/// Glyphe : une onde de points part du logo et traverse le panneau (la « révélation » de l'artifact, où le
/// contenu se décode à sa place). Front net et dense, traîne longue qui s'émiette comme un signal qu'on décode :
/// la taille des points monte par paliers (une trame, pas un dégradé) et un bruit en éteint au hasard dans la traîne.
struct DotWave: View {
    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let origin: CGPoint
    let color: Color

    var body: some View {
        let t = 1 / Motion.speed
        // Pas de la grille, front (net) et traîne (longue) de l'onde, en points ; rayons des quatre paliers.
        let step: CGFloat = 13, lead: CGFloat = 14, trail: CGFloat = 110
        let levels: [CGFloat] = [0.55, 0.95, 1.4, 1.95]
        let corners = [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height),
                       CGPoint(x: size.width, y: size.height)]
        let reach = corners.map { hypot($0.x - origin.x, $0.y - origin.y) }.max() ?? 0
        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, progress in
                view.overlay {
                    if progress > 0.001 && progress < 0.999 {
                        Canvas { context, _ in
                            let front = progress * (reach + trail)
                            let fade = 1 - progress * 0.55
                            // Le bruit change par à-coups (≈ 20 fois par seconde), comme des glyphes qui défilent.
                            let tick = Int(progress * 18)
                            // Les rangées que l'onde n'a pas encore atteintes sont sautées.
                            let maxY = min(size.height, origin.y + front + lead)
                            var row = 0
                            var y = step / 2
                            while y < maxY {
                                var column = 0
                                var x = step / 2
                                while x < size.width {
                                    let d = hypot(x - origin.x, y - origin.y)
                                    let lit = d > front ? 1 - (d - front) / lead : 1 - (front - d) / trail
                                    if lit > 0 {
                                        let noise = DecodeText.noise(column, row, tick)
                                        // Dans la traîne, les points s'éteignent au hasard à mesure que le signal faiblit.
                                        if d > front - 20 || noise < lit * 1.3 {
                                            let r = levels[min(levels.count - 1, Int(lit * CGFloat(levels.count)))]
                                            context.opacity = (0.35 + 0.65 * lit) * fade
                                            context.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)),
                                                         with: .color(color))
                                        }
                                    }
                                    x += step
                                    column += 1
                                }
                                y += step
                                row += 1
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                    }
                }
            } keyframes: { _ in
                LinearKeyframe(0, duration: 0.08 * t)
                CubicKeyframe(1, duration: 0.95 * t)
            }
            .allowsHitTesting(false)
    }
}

/// Glyphe : le titre se décode à sa place, de gauche à droite. Chaque lettre monte en densité (. : = # @),
/// passe par quelques glyphes puis se fige — le « Décodage » de l'artifact. `start` nil ou passé : texte tel quel.
/// `quick` : la version brève de l'utilisation (résultat qui arrive en tapant, ligne qu'on sélectionne).
struct DecodeText: View {
    let text: String
    let start: Date?
    var quick = false
    @StateObject private var reveal = RevealDone()

    static let ramp = Array(".:-=+*#%@")
    static let glyphs = Array("ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&*+=?/")

    var body: some View {
        let duration = Self.duration(text, quick: quick) / Motion.speed
        Group {
            if Motion.enabled, let start, reveal.date != start,
               case let end = start.addingTimeInterval(duration), Date() < end {
                // Le titre garde sa largeur finale pendant le décodage ; VoiceOver lit le texte complet.
                Text(text).opacity(0)
                    .overlay(alignment: .leading) {
                        TimelineView(DecodeSchedule(end: end)) { context in
                            Text(Self.frame(text, progress: context.date.timeIntervalSince(start) / duration))
                        }
                        .accessibilityHidden(true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(text)
            } else {
                Text(text)
            }
        }
        .task(id: start) { await reveal.finish(start, after: duration) }
    }

    /// Les titres longs prennent un peu plus de temps, sans dépasser 0,6 s (0,3 s pour la version brève).
    static func duration(_ text: String, quick: Bool = false) -> TimeInterval {
        quick ? min(0.16 + Double(text.count) * 0.006, 0.3) : min(0.3 + Double(text.count) * 0.012, 0.6)
    }

    /// Le texte à `progress` (0 à 1) : chaque lettre a sa fenêtre, décalée de gauche à droite.
    static func frame(_ text: String, progress: Double) -> String {
        let chars = Array(text)
        let count = Double(max(chars.count, 1))
        let window = 0.4
        let tick = Int(max(progress, 0) * 26)
        var out = ""
        for (i, char) in chars.enumerated() {
            let settle = window + (1 - window) * Double(i) / count
            let phase = (progress - settle + window) / window
            if char == " " || progress >= settle {
                out.append(char)
            } else if phase < 0 {
                out.append(" ")
            } else {
                out.append(symbol(phase: phase, i, 0, tick))
            }
        }
        return out
    }

    /// Caractère d'une lettre (ou d'une case d'icône) en cours de décodage : la rampe de densité,
    /// puis des glyphes qui défilent jusqu'à ce qu'elle se fige.
    static func symbol(phase: Double, _ a: Int, _ b: Int, _ tick: Int) -> Character {
        phase < 0.45
            ? ramp[min(ramp.count - 1, Int(max(phase, 0) / 0.45 * Double(ramp.count)))]
            : glyphs[Int(noise(a, b, tick) * Double(glyphs.count)) % glyphs.count]
    }

    /// Bruit déterministe dans [0, 1) : le même point (ou la même lettre) garde sa valeur pendant un « tick ».
    nonisolated static func noise(_ a: Int, _ b: Int, _ tick: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: a &* 73_856_093 ^ b &* 19_349_663 ^ tick &* 83_492_791)
        h = (h ^ (h >> 13)) &* 0x5bd1_e995
        h ^= h >> 15
        return Double(h % 10_000) / 10_000
    }
}

/// Fin d'un décodage (@State n'est pas disponible sans Xcode complet). Une TimelineView finie peut sauter sa
/// dernière image sous charge : le temps écoulé, on impose l'état final.
@MainActor final class RevealDone: ObservableObject {
    @Published private(set) var date: Date?

    func finish(_ start: Date?, after duration: TimeInterval) async {
        guard let start, Motion.enabled else { return }
        let remaining = max(0, start.addingTimeInterval(duration).timeIntervalSinceNow)
        do { try await Task.sleep(nanoseconds: UInt64(remaining * 1_000_000_000)) }
        catch { return }
        guard !Task.isCancelled else { return }
        date = start
    }
}

/// Glyphe : l'icône se décode comme les titres. Une trame de cases la recouvre ; chacune monte en densité,
/// passe par quelques glyphes puis laisse voir l'image, en diagonale depuis le coin haut gauche, avec un peu
/// de hasard. Seuls le masque et le calque changent : l'icône elle-même n'est jamais recréée (ni rechargée).
struct AsciiReveal: ViewModifier {
    let cue: DecodeCue?
    @StateObject private var reveal = RevealDone()

    func body(content: Content) -> some View {
        if StyleTokens.current.asciiReveal && AppSettings.shared.asciiDecode {
            let start = cue?.start
            let duration = (cue?.quick == true ? 0.24 : 0.42) / Motion.speed
            let end = start?.addingTimeInterval(duration) ?? .distantPast
            let running = Motion.enabled && start != nil && reveal.date != start && Date() < end
            content
                .mask {
                    if running, let start {
                        TimelineView(DecodeSchedule(end: end)) { context in
                            let progress = context.date.timeIntervalSince(start) / duration
                            Canvas { g, size in Self.draw(&g, size: size, progress: progress, mask: true) }
                        }
                    } else {
                        Rectangle()
                    }
                }
                .overlay {
                    if running, let start {
                        TimelineView(DecodeSchedule(end: end)) { context in
                            let progress = context.date.timeIntervalSince(start) / duration
                            Canvas { g, size in Self.draw(&g, size: size, progress: progress, mask: false) }
                        }
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    }
                }
                .task(id: start) { await reveal.finish(start, after: duration) }
        } else {
            content
        }
    }

    /// `mask` : les cases déjà décodées (l'image s'y montre) ; sinon, les caractères des cases en cours.
    /// Cases d'environ 5 pt, entre 4 et 9 par côté.
    private static func draw(_ g: inout GraphicsContext, size: CGSize, progress p: Double, mask: Bool) {
        let n = max(4, min(9, Int((min(size.width, size.height) / 5).rounded())))
        let w = size.width / CGFloat(n), h = size.height / CGFloat(n)
        let window = 0.45
        let tick = Int(max(p, 0) * 26)
        let font = Font.system(size: h * 1.2, weight: .bold, design: .monospaced)
        var resolved: [Character: GraphicsContext.ResolvedText] = [:]
        for row in 0..<n {
            for column in 0..<n {
                let order = Double(column + row) / Double(2 * (n - 1))
                let settle = window + (1 - window) * (0.7 * order + 0.3 * DecodeText.noise(column, row, 7))
                let cell = CGRect(x: CGFloat(column) * w, y: CGFloat(row) * h, width: w, height: h)
                if p >= settle {
                    // Un rien plus grandes : pas de joint entre deux cases voisines.
                    if mask { g.fill(Path(cell.insetBy(dx: -0.5, dy: -0.5)), with: .color(.black)) }
                    continue
                }
                let phase = (p - settle + window) / window
                guard !mask, phase >= 0 else { continue }
                let char = DecodeText.symbol(phase: phase, column, row, tick)
                let text = resolved[char] ?? g.resolve(Text(String(char)).font(font))
                resolved[char] = text
                g.draw(text, at: CGPoint(x: cell.midX, y: cell.midY), anchor: .center)
            }
        }
    }
}

/// Glyphe, version légère des grilles (apps, emoji) : l'élément apparaît d'abord en ASCII, son image en cache,
/// puis passe en fondu à l'image réelle. Un seul fondu d'opacité, joué par Core Animation : rien n'est redessiné
/// image par image, même avec des dizaines d'icônes qui glissent d'une page à l'autre.
struct AsciiFade: ViewModifier {
    let cue: DecodeCue?
    let source: AsciiArt.Source?
    /// Encre de l'ASCII (celle de la sélection sur la case choisie).
    var ink: Color? = nil
    @StateObject private var fade = AsciiFadeState()

    func body(content: Content) -> some View {
        if Motion.decodes {
            content
                .opacity(fade.ascii ? 0 : 1)
                .overlay {
                    if fade.layered, let art = fade.art {
                        Image(nsImage: art).renderingMode(.template).resizable().interpolation(.medium)
                            .aspectRatio(contentMode: .fit)
                            .foregroundStyle(ink.map { AnyShapeStyle($0) } ?? AnyShapeStyle(.primary))
                            .opacity(fade.ascii ? 1 : 0)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                }
                .task(id: source) { fade.load(source) }
                .task(id: cue?.start) { await fade.play(cue) }
        } else {
            content
        }
    }
}

@MainActor final class AsciiFadeState: ObservableObject {
    @Published private(set) var art: NSImage?
    /// L'ASCII remplace l'image (avant le fondu).
    @Published private(set) var ascii = false
    /// Le calque ASCII existe : seulement le temps du fondu, pas de calque de plus le reste du temps.
    @Published private(set) var layered = false
    private var source: AsciiArt.Source?

    func load(_ source: AsciiArt.Source?) {
        guard let source, source != self.source else { return }
        self.source = source
        if let hit = AsciiArt.cached(source) { art = hit; return }
        AsciiArt.request(source) { [weak self] image in
            guard let self, self.source == source else { return }
            art = image
        }
    }

    func play(_ cue: DecodeCue?) async {
        guard let cue, Motion.enabled else { return }
        let wait = cue.start.timeIntervalSinceNow
        if wait > 0 {
            do { try await Task.sleep(nanoseconds: UInt64(wait * 1_000_000_000)) } catch { return }
        }
        // Repère dépassé (case créée en cours de route) : rien à rattraper.
        guard cue.start.timeIntervalSinceNow > -0.15 else { return }
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) {
            ascii = true
            layered = true
        }
        do {
            try await Task.sleep(nanoseconds: UInt64((cue.quick ? 0.05 : 0.1) / Motion.speed * 1_000_000_000))
        } catch {
            withTransaction(instant) { ascii = false; layered = false }
            return
        }
        withAnimation(.easeOut(duration: (cue.quick ? 0.2 : 0.3) / Motion.speed)) {
            ascii = false
        } completion: { [weak self] in
            guard let self, !ascii else { return }
            layered = false
        }
    }
}

/// Glyphe : la version ASCII d'une icône ou d'un caractère. Chaque case prend le caractère de la rampe qui
/// correspond à sa densité (opacité × clarté). Calculée une fois hors du fil principal, puis gardée en cache ;
/// image gabarit, teintée par l'encre.
enum AsciiArt {
    enum Source: Hashable {
        /// Grande icône d'une app (celle de la grille).
        case app(String)
        /// Emoji ou symbole.
        case char(String)

        fileprivate var key: NSString {
            switch self {
            case .app(let path): "A:" + path as NSString
            case .char(let char): "C:" + char as NSString
            }
        }
    }

    private static let cache = NSCache<NSString, NSImage>()
    private static let queue = DispatchQueue(label: "hello.ascii", qos: .userInitiated, attributes: .concurrent)
    /// Cases par côté, pixels par case.
    private static let side = 12
    private static let cell = 16
    private static let ramp = Array(" .:-=+*#%@")

    static func cached(_ source: Source) -> NSImage? { cache.object(forKey: source.key) }

    /// Tout de suite si elle est en cache, sinon calculée à part et rendue sur le fil principal.
    static func request(_ source: Source, done: @escaping (NSImage) -> Void) {
        if let hit = cached(source) { return done(hit) }
        queue.async {
            guard let art = warm(source) else { return }
            DispatchQueue.main.async { done(art) }
        }
    }

    /// Calcule (hors du fil principal) et met en cache.
    @discardableResult
    static func warm(_ source: Source) -> NSImage? {
        if let hit = cached(source) { return hit }
        let image: CGImage?
        switch source {
        case .app(let path):
            image = IconCache.icon(path, large: true).cgImage(forProposedRect: nil, context: nil, hints: nil)
        case .char(let char):
            image = render(char)
        }
        guard let image, let art = make(image) else { return nil }
        cache.setObject(art, forKey: source.key)
        return art
    }

    /// Un caractère dessiné seul, centré (les emoji gardent leurs couleurs, les symboles sont blancs).
    private static func render(_ char: String) -> CGImage? {
        let px = 96
        guard let context = bitmap(px, px) else { return nil }
        let font = CTFontCreateUIFontForLanguage(.system, 72, nil) ?? CTFontCreateWithName("Helvetica" as CFString, 72, nil)
        let line = CTLineCreateWithAttributedString(NSAttributedString(string: char, attributes: [
            NSAttributedString.Key(kCTFontAttributeName as String): font,
            NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
        ]))
        let bounds = CTLineGetBoundsWithOptions(line, .useGlyphPathBounds)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        context.textPosition = CGPoint(x: (CGFloat(px) - bounds.width) / 2 - bounds.minX,
                                       y: (CGFloat(px) - bounds.height) / 2 - bounds.minY)
        CTLineDraw(line, context)
        return context.makeImage()
    }

    /// Les caractères de la rampe, prêts à dessiner (blancs, chasse fixe).
    private static let lines: [CTLine] = {
        let font = CTFontCreateWithName("Menlo-Bold" as CFString, CGFloat(cell) * 1.2, nil)
        return ramp.map { char in
            CTLineCreateWithAttributedString(NSAttributedString(string: String(char), attributes: [
                NSAttributedString.Key(kCTFontAttributeName as String): font,
                NSAttributedString.Key(kCTForegroundColorAttributeName as String): CGColor(gray: 1, alpha: 1),
            ]))
        }
    }()

    private static func make(_ source: CGImage) -> NSImage? {
        let n = side
        // Réduction à une case par pixel : la couleur moyenne de chaque case.
        guard let small = bitmap(n, n) else { return nil }
        small.interpolationQuality = .medium
        small.draw(source, in: CGRect(x: 0, y: 0, width: n, height: n))
        guard let data = small.data?.assumingMemoryBound(to: UInt8.self) else { return nil }
        let size = n * cell
        guard let out = bitmap(size, size) else { return nil }
        for row in 0..<n {
            for column in 0..<n {
                // Première rangée en mémoire : le haut de l'image.
                let p = data + (row * small.bytesPerRow + column * 4)
                let alpha = Double(p[3]) / 255
                guard alpha > 0.02 else { continue }
                let light = (0.3 * Double(p[0]) + 0.59 * Double(p[1]) + 0.11 * Double(p[2])) / 255 / alpha
                let density = alpha * (0.35 + 0.65 * min(light, 1))
                let index = min(ramp.count - 1, Int(density * Double(ramp.count - 1) + 0.5))
                guard index > 0 else { continue }
                let line = lines[index]
                let width = CTLineGetTypographicBounds(line, nil, nil, nil)
                out.textPosition = CGPoint(x: Double(column * cell) + (Double(cell) - width) / 2,
                                           y: Double((n - 1 - row) * cell) + Double(cell) * 0.2)
                CTLineDraw(line, out)
            }
        }
        guard let image = out.makeImage() else { return nil }
        let art = NSImage(cgImage: image, size: NSSize(width: size / 2, height: size / 2))
        art.isTemplate = true
        return art
    }

    private static func bitmap(_ width: Int, _ height: Int) -> CGContext? {
        CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }
}

/// Glyphe : un décodage à jouer, sur un titre ou une icône. `quick` : la version brève de l'utilisation.
struct DecodeCue: Equatable {
    let start: Date
    var quick = false
}

/// Glyphe : quand chaque élément d'une liste ou d'une grille se décode. À l'ouverture complète, tous dans la
/// cascade ; ensuite, en version brève, ceux qui arrivent (en tapant, en changeant d'écran) et celui qu'on
/// sélectionne. Lu et tenu à jour pendant le rendu, sans @Published : il n'en redemande pas.
final class DecodeClock: ObservableObject {
    private var reveal: Date?
    private var seen: [String: DecodeCue] = [:]
    private var selected: String?
    private var selectedAt: Date?

    /// L'arrivée de chaque élément. `reveal` : début de l'ouverture complète (nil : réouverture rapide,
    /// cascade coupée) ; `columns` : grille, la cascade avance d'une rangée à la fois.
    func arrivals(_ ids: [String], selected: String?, reveal: Date?, columns: Int = 1) -> [DecodeCue] {
        let now = Date()
        var next: [String: DecodeCue] = [:]
        if let reveal, reveal != self.reveal, now.timeIntervalSince(reveal) < 0.5 {
            for (i, id) in ids.enumerated() where next[id] == nil {
                next[id] = DecodeCue(start: reveal.addingTimeInterval(RevealStyle.waveDelay(i / max(columns, 1)) / Motion.speed))
            }
            selectedAt = nil
        } else {
            // Les nouveaux venus se décodent presque ensemble, avec un léger décalage de haut en bas.
            for (i, id) in ids.enumerated() where next[id] == nil {
                let order = Double(min(i / max(columns, 1), 12))
                next[id] = seen[id] ?? DecodeCue(start: now.addingTimeInterval(order * 0.018 / Motion.speed), quick: true)
            }
            if let selected, self.selected != nil, selected != self.selected { selectedAt = now }
        }
        self.reveal = reveal
        self.selected = selected
        seen = next
        return ids.map { next[$0]! }
    }

    /// L'arrivée d'un élément, ou son nouveau décodage s'il vient d'être sélectionné.
    func cue(_ arrival: DecodeCue, id: String) -> DecodeCue {
        guard id == selected, let selectedAt, selectedAt > arrival.start else { return arrival }
        return DecodeCue(start: selectedAt, quick: true)
    }
}

/// Glyphe : un texte qui se décode, en version brève, à son apparition et à chaque changement (pied de page,
/// invite de recherche, état vide). Dans les autres styles, un simple Text.
struct LiveDecodeText: View {
    let text: String
    @StateObject private var clock = TextClock()

    init(_ text: String) { self.text = text }

    var body: some View {
        DecodeText(text: text, start: Motion.decodes ? clock.start(for: text) : nil, quick: true)
    }
}

/// Moment où le texte affiché a changé (lu pendant le rendu, sans @Published).
final class TextClock: ObservableObject {
    private var text: String?
    private var date = Date.distantPast

    func start(for text: String) -> Date {
        if text != self.text {
            self.text = text
            date = Date()
        }
        return date
    }
}

/// Images du décodage : 30 par seconde jusqu'à la fin, sans replanifier une date passée.
struct DecodeSchedule: TimelineSchedule {
    let end: Date

    func entries(from date: Date, mode: TimelineScheduleMode) -> [Date] {
        guard date < end else { return [] }
        return Array(stride(from: date, to: end, by: 1.0 / 30)) + [end]
    }
}

/// Phosphore : le faisceau d'électrons balaie l'écran une fois, de haut en bas.
struct ScanBeam: View {
    struct Values {
        var y: CGFloat = 0
        var opacity: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let color: Color

    var body: some View {
        let t = 1 / Motion.speed
        let band: CGFloat = 70
        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay(alignment: .top) {
                    if value.opacity > 0.001 {
                        LinearGradient(colors: [.clear, color.opacity(0.32), color.opacity(0.08), .clear],
                                       startPoint: .top, endPoint: .bottom)
                            .frame(height: band)
                            .offset(y: value.y)
                            .opacity(value.opacity)
                            .blendMode(.plusLighter)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            } keyframes: { _ in
                KeyframeTrack(\.y) {
                    LinearKeyframe(-band, duration: 0.24 * t)
                    LinearKeyframe(size.height, duration: 0.6 * t)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(0, duration: 0.22 * t)
                    LinearKeyframe(1, duration: 0.04 * t)
                    LinearKeyframe(1, duration: 0.52 * t)
                    LinearKeyframe(0, duration: 0.06 * t)
                }
            }
            .allowsHitTesting(false)
    }
}

/// Papier : un trait d'encre se trace sous la recherche, comme au stylo, puis sèche et s'efface.
struct InkStroke: View {
    struct Values {
        var trim: CGFloat = 0
        var opacity: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let line: CGRect
    let color: Color

    var body: some View {
        let t = 1 / Motion.speed
        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay(alignment: .topLeading) {
                    if value.opacity > 0.001 {
                        Path { path in
                            // Légère courbe de main levée.
                            path.move(to: CGPoint(x: line.minX, y: line.minY + 1))
                            path.addQuadCurve(to: CGPoint(x: line.maxX, y: line.minY - 1),
                                              control: CGPoint(x: line.midX, y: line.minY + 3))
                        }
                        .trim(from: 0, to: value.trim)
                        .stroke(color, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .opacity(value.opacity)
                    }
                }
            } keyframes: { _ in
                KeyframeTrack(\.trim) {
                    LinearKeyframe(0, duration: 0.2 * t)
                    CubicKeyframe(1, duration: 0.45 * t)
                }
                KeyframeTrack(\.opacity) {
                    LinearKeyframe(1, duration: 0.05 * t)
                    LinearKeyframe(1, duration: 1.0 * t)
                    CubicKeyframe(0, duration: 0.45 * t)
                }
            }
            .allowsHitTesting(false)
    }
}

/// Néo-brutal : une ombre pleine de la couleur de sélection claque loin du panneau, puis rentre sous l'ombre noire.
struct StampShadow: View {
    struct Values {
        var offset: CGFloat = 0
        var opacity: Double = 0
    }

    let trigger: Int
    let color: Color
    let radius: CGFloat
    let rest: CGFloat

    var body: some View {
        if AppSettings.shared.haloSweep && Motion.enabled {
            let t = 1 / Motion.speed
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            Color.clear
                .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                    view.background {
                        if value.opacity > 0.001 {
                            shape.fill(color)
                                .overlay(shape.strokeBorder(Color.black, lineWidth: 3))
                                .offset(x: value.offset, y: value.offset)
                                .opacity(value.opacity)
                        }
                    }
                } keyframes: { _ in
                    KeyframeTrack(\.offset) {
                        LinearKeyframe(rest, duration: 0.18 * t)
                        SpringKeyframe(rest + 18, duration: 0.2 * t, spring: .init(response: 0.18, dampingRatio: 0.6))
                        SpringKeyframe(rest, duration: 0.5 * t, spring: .init(response: 0.32, dampingRatio: 0.55))
                    }
                    KeyframeTrack(\.opacity) {
                        LinearKeyframe(0, duration: 0.16 * t)
                        LinearKeyframe(1, duration: 0.02 * t)
                        LinearKeyframe(1, duration: 0.7 * t)
                    }
                }
                .allowsHitTesting(false)
        }
    }
}
