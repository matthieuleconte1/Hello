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
    static var enabled: Bool { AppSettings.shared.animations }
    static var amplitude: CGFloat { AppSettings.shared.motionIntensity.amplitude }
    static var speed: Double { AppSettings.shared.animationSpeed }

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
        let hidden = !shown
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
            content.keyframeAnimator(initialValue: 1.0, trigger: trigger) { view, value in
                view.opacity(value)
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(1, duration: 0.32)
                    LinearKeyframe(0.55, duration: 0.03)
                    LinearKeyframe(1, duration: 0.04)
                    LinearKeyframe(0.8, duration: 0.03)
                    LinearKeyframe(1, duration: 0.06)
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
        TimelineView(.periodic(from: .now, by: 0.53)) { context in
            Rectangle()
                .frame(width: height * 0.55, height: height)
                .opacity(Int(context.date.timeIntervalSinceReferenceDate / 0.53) % 2 == 0 ? 1 : 0)
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
struct DecodeText: View {
    let text: String
    let start: Date?

    private static let ramp = Array(".:-=+*#%@")
    private static let glyphs = Array("ABCDEFGHJKLMNPQRSTUVWXYZ0123456789#%&*+=?/")

    var body: some View {
        if let start, case let end = start.addingTimeInterval(Self.duration(text) / Motion.speed), Date() < end {
            TimelineView(DecodeSchedule(end: end)) { context in
                Text(Self.frame(text, progress: context.date.timeIntervalSince(start) / end.timeIntervalSince(start)))
            }
        } else {
            Text(text)
        }
    }

    /// Les titres longs prennent un peu plus de temps, sans dépasser 0,6 s.
    static func duration(_ text: String) -> TimeInterval { min(0.3 + Double(text.count) * 0.012, 0.6) }

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
            } else if phase < 0.45 {
                out.append(ramp[min(ramp.count - 1, Int(phase / 0.45 * Double(ramp.count)))])
            } else {
                out.append(glyphs[Int(noise(i, 0, tick) * Double(glyphs.count)) % glyphs.count])
            }
        }
        return out
    }

    /// Bruit déterministe dans [0, 1) : le même point (ou la même lettre) garde sa valeur pendant un « tick ».
    nonisolated static func noise(_ a: Int, _ b: Int, _ tick: Int) -> Double {
        var h = UInt64(truncatingIfNeeded: a &* 73_856_093 ^ b &* 19_349_663 ^ tick &* 83_492_791)
        h = (h ^ (h >> 13)) &* 0x5bd1_e995
        h ^= h >> 15
        return Double(h % 10_000) / 10_000
    }
}

/// Images du décodage : 30 par seconde jusqu'à la fin, puis plus rien (la vue ne redessine plus).
struct DecodeSchedule: TimelineSchedule {
    let end: Date

    func entries(from date: Date, mode: TimelineScheduleMode) -> [Date] {
        guard date < end else { return [end] }
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
