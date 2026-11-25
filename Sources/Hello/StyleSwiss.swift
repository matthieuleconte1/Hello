import AppKit
import SwiftUI

// Atelier Suisse : d'après le manuel de signalétique des chemins de fer suisses et le style typographique
// international (Josef Müller-Brockmann). Grille visible par des filets fins, hiérarchie portée par la taille
// et la graisse, noir et blanc tranchés, un seul rouge signal comme la trotteuse de l'horloge de gare.
//
// Tout ce qui est propre au style vit ici. Les composants partagés l'appellent par ces points d'entrée :
// `SwissLook` (jetons, mouvement, réglages), `SwissDecor` et les vues `Swiss…` (décor), `SwissSettings` (Réglages › Apparence).

/// Variante de la peau (« Auto » suit l'apparence du Mac).
enum SwissMode: String, CaseIterable, Identifiable {
    case auto, day, night
    var id: String { rawValue }
    var title: String {
        switch self {
        case .auto: "Auto"
        case .day: "Jour"
        case .night: "Nuit"
        }
    }
}

/// Palette de la signalétique : Jour (affiche blanche, encre noire, rouge signal) et Nuit (tableau de départ nocturne).
enum SwissPalette {
    // Jour : blanc pur, encre presque noire, secondaire gris neutre, rouge signal d'horloge de gare.
    static let dayFrame = Color(hex: "#FFFFFF")
    static let dayPane = Color(hex: "#FFFFFF")
    static let dayInk = Color(hex: "#0D0D0D")
    static let daySecondary = Color(hex: "#6B6B68")
    static let dayRed = Color(hex: "#E10600")
    static let daySelection = Color(hex: "#0D0D0D")
    static let daySelectionInk = Color(hex: "#FFFFFF")

    // Nuit : tableau de départ nocturne, fond noir profond, champ légèrement relevé, blanc chaud, rouge lumineux.
    static let nightFrame = Color(hex: "#0D0D0D")
    static let nightPane = Color(hex: "#121212")
    static let nightInk = Color(hex: "#F7F7F5")
    static let nightSecondary = Color(hex: "#8A8A86")
    static let nightRed = Color(hex: "#FF241C")
    static let nightSelection = Color(hex: "#F7F7F5")
    static let nightSelectionInk = Color(hex: "#0D0D0D")
    static let nightKeyFill = Color(hex: "#1A1A1A")

    static func red(dark: Bool) -> Color { dark ? nightRed : dayRed }
}

/// Ce que le décor d'Atelier Suisse a besoin de savoir pour se dessiner.
struct SwissDecor {
    var dark: Bool
    var frame: Color
    var pane: Color
    var ink: Color
    var secondary: Color
    var accent: Color
    var grid: Bool
    var monoIcons: Bool
}

enum SwissLook {
    static let detail = "Style typographique international et signalétique ferroviaire : grille fine, noir et blanc, un rouge signal."
    static let symbol = "clock"
    static let summary = "le panneau glisse de 12 pt et se verrouille sans rebond ; les lignes basculent comme un tableau à palettes, décalées de 25 ms."
    static let effect = "la trotteuse rouge fait un tour autour du logo pendant qu'une palette bascule sous la recherche."

    /// Variante sombre active.
    static var isDark: Bool {
        let mode = AppSettings.shared.swissMode
        if mode == .auto { return StyleTokens.systemIsDark }
        return mode == .night
    }

    /// Ce qui change l'aspect du champ de recherche.
    static var signature: String {
        let s = AppSettings.shared
        return "\(s.swissMode.rawValue)|\(s.swissGrid)"
    }

    /// « Réinitialiser l'apparence » : remet les réglages de la peau par défaut.
    static func resetSettings(_ s: AppSettings) {
        s.swissMode = .auto
        s.swissGrid = true
        s.swissMonoIcons = true
    }

    static var tokens: StyleTokens {
        let p = SwissPalette.self
        let settings = AppSettings.shared
        let dark = isDark
        let frame = dark ? p.nightFrame : p.dayFrame
        let pane = dark ? p.nightPane : p.dayPane
        let ink = dark ? p.nightInk : p.dayInk
        let secondary = dark ? p.nightSecondary : p.daySecondary
        let accent = p.red(dark: dark)

        return StyleTokens(
            // Surface pleine (pas `.inset`, qui forcerait un arrondi intérieur de 8 pt dans un cadre de 4 pt).
            // En Nuit, `SwissSurface` peint le champ central `#121212` bord à bord entre les deux filets.
            surface: .solid(frame),
            dark: dark,
            ink: ink,
            chromeInk: ink,
            chromeDark: dark,
            accent: accent,
            accent2: ink,
            live: accent,
            toast: accent,
            // Inversion franche pleine largeur, sans bordure ni ombre.
            selectionFill: dark ? p.nightSelection : p.daySelection,
            selectionInk: dark ? p.nightSelectionInk : p.daySelectionInk,
            selectionBorder: nil,
            selectionBar: nil,
            selectionHardShadow: nil,
            rowRadius: 0,
            cellRadius: 2,
            radius: 4,
            border: (dark ? ink.opacity(0.45) : ink, 1.5),
            divider: ink.opacity(dark ? 0.24 : 0.28),
            design: .default,
            searchWidth: .condensed,
            titleWeight: .medium,
            searchWeight: .bold,
            header: .kicker,
            markSkin: .swiss(ink: ink, dot: accent),
            iconButton: (fill: ink, ink: frame),
            strongMeta: true,
            keyFill: dark ? p.nightKeyFill : p.dayFrame,
            keyInk: ink.opacity(0.90),
            keyBorder: ink.opacity(dark ? 0.36 : 0.45),
            primaryKeyFill: accent,
            primaryKeyInk: .white,
            chromeCaps: true,
            launchTint: accent,
            tile: .decor,
            iconSaturation: settings.swissMonoIcons ? 0.0 : 1.0,
            iconOpacity: 1.0,
            // Saut mécanique sec sans rebond.
            motion: .timingCurve(0.2, 0.9, 0.25, 1, duration: 0.10),
            decor: .swiss(SwissDecor(
                dark: dark,
                frame: frame,
                pane: pane,
                ink: ink,
                secondary: secondary,
                accent: accent,
                grid: settings.swissGrid,
                monoIcons: settings.swissMonoIcons
            ))
        )
    }

    /// Fond derrière la vignette (Réglages et aperçus) : béton d'architecture en Jour, ardoise mate en Nuit.
    @ViewBuilder static var backdrop: some View {
        if isDark {
            LinearGradient(colors: [Color(hex: "#2C2C2A"), Color(hex: "#181817")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        } else {
            LinearGradient(colors: [Color(hex: "#C6C6C2"), Color(hex: "#9A9A95")],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    // MARK: Mouvement

    /// Glissement sec qui se verrouille sans aucun rebond.
    static func open(light: Bool) -> Animation {
        light ? .timingCurve(0.16, 1, 0.3, 1, duration: 0.13)
              : .timingCurve(0.2, 0.85, 0.25, 1, duration: 0.3)
    }

    static let navigation = Animation.timingCurve(0.2, 0.9, 0.25, 1, duration: 0.16)

    static func modeTransition(forward: Bool) -> AnyTransition {
        let k = Motion.amplitude
        let side: CGFloat = forward ? 1 : -1
        return .asymmetric(
            insertion: .offset(x: 14 * k * side).combined(with: .opacity),
            removal: .offset(x: -10 * k * side).combined(with: .opacity)
        )
    }

    /// Tableau à palettes : chaque ligne tombe de sa charnière et claque en place, 35 ms après la précédente.
    /// La courbe accélère jusqu'au bout puis s'arrête net, comme une palette qui vient buter.
    static func row(_ order: Int) -> Animation {
        .timingCurve(0.55, 0, 0.75, 0.25, duration: 0.2).delay(0.06 + Double(min(order, 12)) * 0.035)
    }

    /// Angle de départ d'une ligne (palette relevée vers l'arrière).
    static let rowTilt: Double = -88

    static let close = Animation.easeIn(duration: 0.14)
    static var rowOffset: CGSize { .zero }
    static let rowScale: CGFloat = 1
}

/// Le panneau entier : glisse de 12 pt et se verrouille sans rebond ; au lancement, retrait net vers le haut.
struct SwissPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        let k = Motion.amplitude * (light ? 0.35 : 1)
        let close = Motion.scaled(SwissLook.close)
        // Le panneau se déroule depuis la barre de recherche comme un store de quai, sans rebond.
        content
            .offset(y: closing ? -8 * k : 0)
            .opacity(closing ? 0.45 : 1)
            .animation(close, value: closing)
            .mask(alignment: .top) {
                // Marge négative : le masque déborde pour ne jamais rogner l'ombre portée du panneau.
                Rectangle().padding(-60).scaleEffect(x: 1, y: hidden && !light ? 0.2 : 1, anchor: .top)
            }
            .offset(y: hidden ? -10 * k : 0)
            .opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture : la trotteuse rouge fait un tour autour du logo avec la brève pause suisse à midi,
/// tandis qu'une palette de tableau de départ bascule sous la recherche (rotation X).
struct SwissOpening: View {
    struct Values {
        var handAngle: Double = 0
        var handOpacity: Double = 0
        var flapAngle: Double = -88
        var flapOpacity: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        let t = 1 / Motion.speed
        let amp = Double(min(max(Motion.amplitude, 0.5), 1.4))
        let isFull = size.height > 200
        let headerY: CGFloat = isFull ? 60 : (size.height > 72 ? size.height * (40.0 / 190.0) : max(size.height - 4, 2))
        let markCenter = CGPoint(x: isFull ? 29 : 20, y: isFull ? 30 : headerY / 2)
        let handLength: CGFloat = isFull ? 13 : 9
        let discDiameter: CGFloat = isFull ? 4.5 : 3.2

        Color.clear
            .frame(width: size.width, height: size.height)
            .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                view.overlay(alignment: .topLeading) {
                    ZStack(alignment: .topLeading) {
                        // 1. La trotteuse rouge autour du logo.
                        if value.handOpacity > 0.002 {
                            ZStack {
                                // Tige fine + disque rouge signature de la trotteuse de gare.
                                VStack(spacing: 0) {
                                    Circle()
                                        .fill(tokens.accent)
                                        .frame(width: discDiameter, height: discDiameter)
                                    Rectangle()
                                        .fill(tokens.accent)
                                        .frame(width: 1.2, height: handLength * 0.72)
                                    Spacer(minLength: 0)
                                }
                                .frame(height: handLength * 1.45)
                                .offset(y: -handLength * 0.25)
                            }
                            .frame(width: handLength * 2, height: handLength * 2)
                            .rotationEffect(.degrees(value.handAngle))
                            .position(markCenter)
                            .opacity(value.handOpacity)
                        }

                        // 2. Palette qui bascule sous la recherche (rotation 3D sur l'axe X), alignée sur la colonne de grille.
                        if value.flapOpacity > 0.002 && size.height > 72 {
                            HStack(spacing: 0) {
                                Rectangle()
                                    .fill(tokens.accent)
                                    .frame(width: isFull ? 41.5 : 30)
                                    .padding(.leading, isFull ? 8 : 6)
                                Rectangle()
                                    .fill(tokens.ink.opacity(tokens.dark ? 0.55 : 0.75))
                            }
                            .frame(width: size.width, height: 3.5)
                            .rotation3DEffect(
                                .degrees(value.flapAngle * amp),
                                axis: (x: 1, y: 0, z: 0),
                                anchor: .top,
                                perspective: 0.45
                            )
                            .offset(y: headerY)
                            .opacity(value.flapOpacity)
                        }
                    }
                    .frame(width: size.width, height: size.height, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                }
            } keyframes: { _ in
                KeyframeTrack(\.handAngle) {
                    LinearKeyframe(0, duration: 0.015 * t)
                    CubicKeyframe(360, duration: 0.34 * t)
                    // Brève pause caractéristique à 12 h avant effacement.
                    LinearKeyframe(360, duration: 0.09 * t)
                }
                KeyframeTrack(\.handOpacity) {
                    LinearKeyframe(1, duration: 0.02 * t)
                    LinearKeyframe(1, duration: 0.34 * t)
                    CubicKeyframe(0, duration: 0.085 * t)
                }
                KeyframeTrack(\.flapAngle) {
                    LinearKeyframe(-88, duration: 0.02 * t)
                    CubicKeyframe(0, duration: 0.16 * t)
                    LinearKeyframe(0, duration: 0.14 * t)
                    CubicKeyframe(85, duration: 0.11 * t)
                }
                KeyframeTrack(\.flapOpacity) {
                    LinearKeyframe(0.95, duration: 0.02 * t)
                    LinearKeyframe(0.95, duration: 0.30 * t)
                    CubicKeyframe(0, duration: 0.11 * t)
                }
            }
            .allowsHitTesting(false)
    }
}

/// Grain d'émail mat (tableau de quai la nuit, papier couché le jour), partagé via `Grain`.
private enum SwissTextures {
    static func matte(dark: Bool) -> NSImage {
        Grain.tile(dark
            ? Grain.Spec(amount: 0.085, lightShare: 0.9, specks: 0.002, seed: 0x2F19_8C4A_9103_E6B1)
            : Grain.Spec(amount: 0.07, shadow: .init(r: 0.10, g: 0.09, b: 0.08), lightShare: 0.55, specks: 0.004,
                         seed: 0x7B4E_12D8_3C5A_09F3))
    }
}

/// Fond du cadre (sous le contenu) : en Nuit, champ central `#121212` entre en-tête et pied de page ;
/// grille typographique suisse par des filets fins verticaux qui structurent les colonnes sans gêner la lecture.
struct SwissSurface: View {
    let decor: SwissDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let isFull = w >= 420 && h >= 220
            let isSample = !isFull && w >= 200 && h >= 120
            let headerH: CGFloat = isFull ? 60 : (isSample ? h * (40.0 / 190.0) : h * (40.0 / 190.0))
            let footerH: CGFloat = isFull ? 40 : (isSample ? h * (26.0 / 190.0) : h * (26.0 / 190.0))

            ZStack(alignment: .topLeading) {
                // En Nuit, le champ central du tableau de départ se détache légèrement (#121212 sur #0D0D0D).
                if decor.dark && h > headerH + footerH + 4 {
                    Rectangle()
                        .fill(decor.pane)
                        .frame(width: w, height: h - headerH - footerH)
                        .offset(y: headerH)
                }

                // Grain mat très discret (émail de panneau / papier couché mat).
                Rectangle()
                    .fill(ImagePaint(image: Image(nsImage: SwissTextures.matte(dark: decor.dark))))

                // Grille typographique suisse : marge extérieure de la zone de contenu (8 pt), gouttière icône/titre (49,5 pt),
                // et colonne dédiée aux accessoires de droite (w - 110 pt). Aucun filet ne touche un glyphe ni une icône.
                if decor.grid && (isFull || isSample) {
                    Canvas { ctx, size in
                        let lineColor = decor.ink.opacity(decor.dark ? 0.09 : 0.085)
                        let columns: [CGFloat] = isFull
                            ? [8, 49.5, size.width - 110, size.width - 8]
                            : [6, 36, size.width - 6]

                        for x in columns {
                            let alignedX = floor(x) + 0.25
                            var path = Path()
                            path.move(to: CGPoint(x: alignedX, y: headerH))
                            path.addLine(to: CGPoint(x: alignedX, y: max(headerH, size.height - footerH)))
                            ctx.stroke(path, with: .color(lineColor), lineWidth: 0.5)
                        }

                        // Repères de cadrage discrets en bordure haute et basse sur la marge de la grille.
                        let tickColor = decor.ink.opacity(decor.dark ? 0.22 : 0.24)
                        let tickLen: CGFloat = isFull ? 4 : 2.5
                        for x in [columns.first, columns.last].compactMap({ $0 }) {
                            let alignedX = floor(x) + 0.25
                            var topTick = Path()
                            topTick.move(to: CGPoint(x: alignedX, y: 0))
                            topTick.addLine(to: CGPoint(x: alignedX, y: tickLen))
                            ctx.stroke(topTick, with: .color(tickColor), lineWidth: 0.75)

                            var botTick = Path()
                            botTick.move(to: CGPoint(x: alignedX, y: size.height - tickLen))
                            botTick.addLine(to: CGPoint(x: alignedX, y: size.height))
                            ctx.stroke(botTick, with: .color(tickColor), lineWidth: 0.75)
                        }
                    }
                }
            }
        }
        .clipShape(shape)
        .allowsHitTesting(false)
    }
}

/// Fond du panneau intérieur (conservé pour compatibilité de signature ; `.solid` utilise `SwissSurface`).
struct SwissPane: View {
    let decor: SwissDecor
    let radius: CGFloat

    var body: some View {
        EmptyView()
    }
}

/// Par-dessus le surlignage de la ligne choisie : ponctuée d'un disque rouge signal de 7 pt
/// en haut à droite, hors du texte des accessoires.
struct SwissSelection: View {
    let decor: SwissDecor
    let radius: CGFloat

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let tiny = height < 16
            let medium = height < 32
            let dotSize: CGFloat = tiny ? 2.5 : (medium ? 4.5 : 7)
            let topInset: CGFloat = tiny ? 1.5 : (medium ? 3.5 : 4.5)
            let trailingInset: CGFloat = tiny ? 2 : (medium ? 4 : 5)

            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Circle()
                        .fill(decor.accent)
                        .frame(width: dotSize, height: dotSize)
                        .padding(.top, topInset)
                        .padding(.trailing, trailingInset)
                }
                Spacer(minLength: 0)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Séparateurs comme une grille d'affiche : filet noir/blanc franc sous la recherche avec barre signal rouge
/// alignée sur le logo, filet de grille avec repères de colonnes au-dessus du pied de page.
struct SwissDivider: View {
    let decor: SwissDecor
    let vertical: Bool
    let role: StyleDivider.Role

    var body: some View {
        if vertical {
            Rectangle()
                .fill(decor.ink.opacity(decor.dark ? 0.28 : 0.38))
                .frame(width: 1)
                .allowsHitTesting(false)
        } else {
            GeometryReader { geo in
                let w = geo.size.width
                let isFull = w >= 420
                switch role {
                case .header:
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(decor.ink.opacity(decor.dark ? 0.78 : 0.96))
                            .frame(height: 1.5)
                        // Segment rouge signal verrouillé sur la première colonne de la grille (8 → 49,5 pt).
                        Rectangle()
                            .fill(decor.accent)
                            .frame(width: isFull ? 41.5 : 30, height: 2.5)
                            .offset(x: isFull ? 8 : 6)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                case .footer:
                    ZStack(alignment: .topLeading) {
                        Rectangle()
                            .fill(decor.ink.opacity(decor.dark ? 0.34 : 0.50))
                            .frame(height: 1)
                        if decor.grid && w >= 200 {
                            let columns: [CGFloat] = isFull
                                ? [8, 49.5, w - 110, w - 8]
                                : [6, 36, w - 6]
                            ForEach(Array(columns.enumerated()), id: \.offset) { _, x in
                                Rectangle()
                                    .fill(decor.ink.opacity(decor.dark ? 0.45 : 0.60))
                                    .frame(width: 1, height: 4)
                                    .offset(x: floor(x), y: -3)
                            }
                        }
                    }
                case .plain:
                    Rectangle()
                        .fill(decor.ink.opacity(decor.dark ? 0.24 : 0.28))
                        .frame(height: 1)
                }
            }
            .allowsHitTesting(false)
        }
    }
}

/// Pastille de pictogramme ferroviaire : noir et blanc contrasté au repos, couleur révélée sur la ligne choisie.
struct SwissTile: View {
    let decor: SwissDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let corner: CGFloat = side >= 16 ? 2 : 1
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)
            // Au repos : plaque monochrome à filet franc. Sélectionnée : la couleur (ou le rouge signal) se révèle.
            let activeFill = tint == .gray ? decor.accent : tint
            let fill: Color = selected ? activeFill : (decor.dark ? Color(hex: "#181816") : Color(hex: "#FFFFFF"))
            let glyphColor: Color = selected ? .white : decor.ink

            ZStack {
                shape.fill(fill)
                if !selected {
                    shape.strokeBorder(decor.ink.opacity(decor.dark ? 0.48 : 0.85), lineWidth: side >= 16 ? 1 : 0.6)
                }
                if side >= 10 {
                    Image(systemName: name)
                        .font(.system(size: side * 0.50, weight: .semibold))
                        .foregroundStyle(glyphColor)
                }
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .padding(1)
    }
}

/// Anneau du logo façon horloge de gare : bouts droits géométriques et fine lunette de cadran.
struct SwissMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            ZStack {
                if side >= 16 {
                    Circle()
                        .inset(by: 0.5)
                        .stroke(ink.opacity(0.18), lineWidth: 0.6)
                }
                MarkRing()
                    .trim(from: 0, to: progress)
                    .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .butt))
            }
            .frame(width: side, height: side)
        }
    }
}

/// Point du logo : le disque rouge signal de la trotteuse d'horloge de gare.
struct SwissMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        let diameter = 2.25 * radius
        Circle()
            .fill(dot)
            .frame(width: diameter, height: diameter)
    }
}

/// Réglages › Apparence, quand Atelier Suisse est choisi.
struct SwissSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Variante", selection: $settings.swissMode) {
                ForEach(SwissMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Grille typographique", isOn: $settings.swissGrid)
            Toggle("Icônes en noir et blanc", isOn: $settings.swissMonoIcons)
        } header: {
            Text("Atelier Suisse")
        } footer: {
            Text("Jour (affiche blanche) ou Nuit (tableau de départ nocturne). Filets de grille modulaires et unique rouge signal.")
        }
    }
}
