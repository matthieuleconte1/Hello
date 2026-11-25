import AppKit
import SwiftUI

// E-Encre : le calme d'une dalle à encre électronique (liseuse, reMarkable).
// Matière gris minéral froid (à distinguer de Papier, crème et vermillon) : ni accent coloré, ni flou,
// ni transparence, ni dégradé. En Nuit, éclairage frontal ambré sur dalle sombre. Sélection en vidéo inverse
// pure et instantanée ; à l'ouverture, un bref flash d'inversion (~55 ms) puis plus aucune animation.
//
// Tout ce qui est propre au style vit ici. Les composants partagés l'appellent par ces points d'entrée :
// `EInkLook` (jetons, mouvement, réglages), `EInkDecor` et les vues `EInk…` (décor), `EInkSettings` (Réglages › Apparence).

/// Variante de la peau (« Auto » suit l'apparence du Mac).
enum EInkMode: String, CaseIterable, Identifiable {
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

/// Palette de la dalle à encre électronique : gris minéral froid le jour, éclairage frontal ambré la nuit.
private enum EInkPalette {
    // Jour : gris minéral froid, contraste mat ~15:1.
    static let dayFrame = Color(hex: "#CECFCA")
    static let dayPane = Color(hex: "#E5E6E1")
    static let dayInk = Color(hex: "#141414")
    static let daySecondary = Color(hex: "#595A56")
    static let dayBorder = Color(hex: "#2E2F2C")
    static let dayPaneBorder = Color(hex: "#868882")
    static let dayShadow = Color(hex: "#2E2F2C").opacity(0.32)

    // Nuit : éclairage frontal ambré, encre chaude sur dalle sombre.
    static let nightFrame = Color(hex: "#22201B")
    static let nightPane = Color(hex: "#1A1915")
    static let nightInk = Color(hex: "#E5DEC9")
    static let nightSecondary = Color(hex: "#9E9785")
    static let nightBorder = Color(hex: "#575246")
    static let nightPaneBorder = Color(hex: "#423E35")
    static let nightShadow = Color(hex: "#0A0907").opacity(0.55)
}

/// Ce que le décor de la peau a besoin de savoir pour se dessiner.
struct EInkDecor {
    var dark: Bool
    var ink: Color
    var accent: Color
    var frame: Color
    var pane: Color
    var secondary: Color
    var border: Color
    var grain: Bool
    var ditherTiles: Bool
}

enum EInkLook {
    static let detail = "Dalle à encre électronique : gris minéral froid, contraste mat, vidéo inverse."
    static let symbol = "book.pages"
    static let summary = "rafraîchissement complet de la dalle (négatif, noir, blanc), puis les lignes s'impriment par bandes."
    static let effect = "la dalle passe en négatif, se vide en noir puis en blanc, et la page revient avec une légère rémanence."

    /// Variante sombre active.
    static var isDark: Bool {
        let mode = AppSettings.shared.einkMode
        if mode == .auto { return StyleTokens.systemIsDark }
        return mode == .night
    }

    /// Ce qui change l'aspect du champ de recherche (ajouter ici les réglages de la peau qui le touchent).
    static var signature: String {
        let s = AppSettings.shared
        return "\(s.einkMode.rawValue)|\(s.einkGrain)|\(s.einkDitherTiles)"
    }

    /// « Réinitialiser l'apparence » : remet les réglages de la peau par défaut.
    static func resetSettings(_ s: AppSettings) {
        s.einkMode = .auto
        s.einkGrain = true
        s.einkDitherTiles = true
    }

    /// Police à empattements présente sur macOS : Charter par défaut, Georgia en repli.
    private static let bodyFamily: String? = {
        for family in ["Charter", "Georgia"] {
            if NSFontManager.shared.font(withFamily: family, traits: [], weight: 5, size: 13) != nil {
                return family
            }
        }
        return nil
    }()

    static var tokens: StyleTokens {
        let p = EInkPalette.self
        let settings = AppSettings.shared
        let dark = isDark
        let frame = dark ? p.nightFrame : p.dayFrame
        let pane = dark ? p.nightPane : p.dayPane
        let ink = dark ? p.nightInk : p.dayInk
        let secondary = dark ? p.nightSecondary : p.daySecondary
        let border = dark ? p.nightBorder : p.dayBorder
        let paneBorder = dark ? p.nightPaneBorder : p.dayPaneBorder

        return StyleTokens(
            surface: .inset(frame: frame, pane: pane),
            dark: dark,
            ink: ink,
            chromeInk: ink,
            chromeDark: dark,
            accent: ink,
            accent2: secondary,
            live: ink,
            toast: ink,
            // Vidéo inverse pure, coins 3 pt, contraste ~15:1.
            selectionFill: ink,
            selectionInk: pane,
            selectionBorder: nil,
            selectionBorderWidth: 1,
            rowRadius: 3,
            cellRadius: 4,
            // Panneau : rayon 10, bordure 1,5 pt, ombre courte et mate (sans flou).
            radius: 10,
            border: (border, 1.5),
            hardShadow: 3,
            hardShadowColor: dark ? p.nightShadow : p.dayShadow,
            divider: .clear,
            design: .serif,
            titleDesign: .serif,
            titleWeight: .semibold,
            searchWeight: .regular,
            header: .label,
            markSkin: .eink(ink: ink, dot: ink),
            fontFamily: bodyFamily,
            displayFamily: bodyFamily,
            paneBorder: paneBorder,
            iconButton: (fill: pane, ink: ink),
            strongMeta: true,
            // Touches plates et mates, chasse fixe ; ↵ en vidéo inverse.
            keyFill: pane,
            keyInk: ink,
            keyBorder: border.opacity(dark ? 0.85 : 0.72),
            primaryKeyFill: ink,
            primaryKeyInk: pane,
            keyHardShadow: false,
            keyRaised: false,
            monoKeys: true,
            sectionRule: ink.opacity(dark ? 0.24 : 0.22),
            launchTint: ink,
            tile: .decor,
            // Icônes en niveaux de gris calées sur le ton de la dalle, cernées d'un filet d'encre
            // pour rester nettes même lorsque l'icône (Notes le jour, Terminal la nuit) rejoint le fond.
            iconTint: dark ? p.nightInk : p.dayPane,
            iconSaturation: 0,
            iconOpacity: 1.0,
            iconOutline: true,
            iconEdges: 0.28,
            monochrome: ink,
            // Sélection instantanée : aucun glissement.
            motion: nil,
            decor: .eink(EInkDecor(
                dark: dark,
                ink: ink,
                accent: ink,
                frame: frame,
                pane: pane,
                secondary: secondary,
                border: border,
                grain: settings.einkGrain,
                ditherTiles: settings.einkDitherTiles
            ))
        )
    }

    /// Fond mat derrière la vignette (Réglages et aperçus) : ardoise froide le jour, pierre sombre la nuit.
    @ViewBuilder static var backdrop: some View {
        Color(hex: isDark ? "#3B3831" : "#565854")
    }

    // MARK: Mouvement (e-ink : instantané, aucune cascade animée)

    static func open(light: Bool) -> Animation { .linear(duration: 0.001) }
    static let navigation = Animation.linear(duration: 0.001)
    static func modeTransition(forward: Bool) -> AnyTransition { .identity }
    /// Rafraîchissement partiel : après le flash, les lignes s'impriment par bandes, de haut en bas, sans fondu.
    static func row(_ order: Int) -> Animation {
        .linear(duration: 0.001).delay(0.2 + Double(min(order, 12)) * 0.045)
    }
    static let close = Animation.linear(duration: 0.001)
    static var rowOffset: CGSize { .zero }
    static let rowScale: CGFloat = 1
}

/// Le panneau entier : apparition nette sans glissement ni ressort, fidèle à une dalle e-ink.
struct EInkPanelMotion: ViewModifier {
    let hidden: Bool
    let closing: Bool
    let light: Bool
    let revealID: Int

    func body(content: Content) -> some View {
        content
            .opacity(hidden ? 0 : 1)
    }
}

/// Effet d'ouverture : un vrai rafraîchissement complet de dalle e-ink. L'image passe en négatif, puis la dalle
/// se vide (aplat noir puis blanc, deux temps francs), et la page revient avec une rémanence grise qui s'efface
/// par paliers. Rien ne glisse ni ne fond : chaque état est tenu, comme sur une liseuse.
struct EInkOpening: View {
    struct Values {
        /// 0 : repos ; 1 : négatif ; 2 : aplat d'encre ; 3 : aplat blanc.
        var phase: Double = 0
        /// Rémanence (ghosting) juste après le retour à l'image.
        var ghost: Double = 0
    }

    let trigger: Int
    let size: CGSize
    let radius: CGFloat
    let tokens: StyleTokens

    var body: some View {
        if Motion.enabled {
            let t = 1 / Motion.speed
            let amp = Double(min(max(Motion.amplitude, 0.45), 1.4))
            let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
            // Couleur de référence pour `.difference` : inverse exactement la dalle en négatif.
            let invertColor = tokens.dark ? Color(hex: "#EFE7D2") : Color(hex: "#ECECE8")
            let inkFill = tokens.dark ? Color(hex: "#EFE7D2") : Color(hex: "#1A1A18")
            let paperFill = tokens.dark ? Color(hex: "#151513") : Color(hex: "#ECECE8")

            Color.clear
                .frame(width: size.width, height: size.height)
                .keyframeAnimator(initialValue: Values(), trigger: trigger) { view, value in
                    view.overlay {
                        switch value.phase {
                        case 0.5..<1.5:
                            shape.fill(invertColor).blendMode(.difference)
                        case 1.5..<2.5:
                            shape.fill(inkFill)
                        case 2.5..<3.5:
                            shape.fill(paperFill)
                        default:
                            if value.ghost > 0.01 {
                                // Rémanence : l'ancienne image en négatif, très pâle, qui s'efface par paliers.
                                shape.fill(invertColor.opacity(0.22 * amp * value.ghost)).blendMode(.difference)
                            }
                        }
                    }
                } keyframes: { _ in
                    KeyframeTrack(\.phase) {
                        LinearKeyframe(1, duration: 0.001)
                        LinearKeyframe(1, duration: 0.07 * t)
                        LinearKeyframe(2, duration: 0.001)
                        LinearKeyframe(2, duration: 0.055 * t)
                        LinearKeyframe(3, duration: 0.001)
                        LinearKeyframe(3, duration: 0.06 * t)
                        LinearKeyframe(0, duration: 0.001)
                    }
                    KeyframeTrack(\.ghost) {
                        LinearKeyframe(0, duration: 0.187 * t)
                        LinearKeyframe(1, duration: 0.001)
                        LinearKeyframe(1, duration: 0.06 * t)
                        LinearKeyframe(0.55, duration: 0.001)
                        LinearKeyframe(0.55, duration: 0.06 * t)
                        LinearKeyframe(0.2, duration: 0.001)
                        LinearKeyframe(0.2, duration: 0.06 * t)
                        LinearKeyframe(0, duration: 0.001)
                    }
                }
                .allowsHitTesting(false)
        } else {
            Color.clear
                .frame(width: size.width, height: size.height)
                .allowsHitTesting(false)
        }
    }
}

// MARK: - Matière e-ink (motifs bitmap Retina calculés une seule fois et mis en cache)

private enum EInkTextures {

    // Trames de Bayer 4×4 pour les pastilles et le tramage monochrome.
    static let bayerLightDay = makeBayer(density: 4, inkHex: 0x141414, alpha: 0.28)
    static let bayerLightNight = makeBayer(density: 4, inkHex: 0xE5DEC9, alpha: 0.30)

    /// Microcapsules de la dalle : grain minéral net, plus franc sur le bord mat.
    static func slabGrain(dark: Bool) -> NSImage {
        Grain.tile(Grain.Spec(amount: dark ? 0.10 : 0.11, lightShare: dark ? 0.7 : 0.5, specks: 0.008,
                              seed: dark ? 0x6E31_9D4B_2A87_C513 : 0x4C7A_E109_8F32_B6D1))
    }
    static func bezelGrain(dark: Bool) -> NSImage {
        Grain.tile(Grain.Spec(amount: dark ? 0.12 : 0.14, lightShare: 0.6, specks: 0.01,
                              seed: dark ? 0x91B4_3C2F_7D50_E8A9 : 0x2F85_A61C_D904_73E5))
    }
    static func bayerTile(dark: Bool) -> NSImage { dark ? bayerLightNight : bayerLightDay }

    /// Matrice de Bayer 4×4 ordonnée (valeurs 0…15) : trame franche en points carrés 1 pt.
    private static let bayer4x4: [[Int]] = [
        [0,  8,  2, 10],
        [12, 4, 14,  6],
        [3, 11,  1,  9],
        [15, 7, 13,  5],
    ]

    private static func makeBayer(density: Int, inkHex: UInt32, alpha: Double) -> NSImage {
        let side = 4, scale = 2
        let r = Double((inkHex >> 16) & 0xFF) / 255.0
        let g = Double((inkHex >> 8) & 0xFF) / 255.0
        let b = Double(inkHex & 0xFF) / 255.0
        return bitmap(width: side, height: side, scale: scale) { data, pxW, pxH in
            for y in 0..<pxH {
                for x in 0..<pxW {
                    let on = bayer4x4[(y / scale) % 4][(x / scale) % 4] < density
                    let idx = (y * pxW + x) * 4
                    if on {
                        let a = UInt8(min(max(alpha * 255.0, 0), 255))
                        data[idx] = UInt8(r * Double(a))
                        data[idx + 1] = UInt8(g * Double(a))
                        data[idx + 2] = UInt8(b * Double(a))
                        data[idx + 3] = a
                    } else {
                        data[idx] = 0
                        data[idx + 1] = 0
                        data[idx + 2] = 0
                        data[idx + 3] = 0
                    }
                }
            }
        }
    }

    private static func bitmap(width: Int, height: Int, scale: Int,
                               fill: (UnsafeMutablePointer<UInt8>, Int, Int) -> Void) -> NSImage {
        let pxW = width * scale
        let pxH = height * scale
        guard let ctx = CGContext(data: nil, width: pxW, height: pxH, bitsPerComponent: 8, bytesPerRow: pxW * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let raw = ctx.data?.assumingMemoryBound(to: UInt8.self) else {
            return NSImage(size: NSSize(width: width, height: height))
        }
        fill(raw, pxW, pxH)
        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: width, height: height)) }
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
}

// MARK: - Décor de la dalle

/// Fond du cadre (bord de dalle gris minéral froid, sans dégradé ni reflet).
struct EInkSurface: View {
    let decor: EInkDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            if decor.grain {
                Rectangle()
                    .fill(ImagePaint(image: Image(nsImage: EInkTextures.bezelGrain(dark: decor.dark))))
                    .clipShape(shape)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Fond du panneau intérieur (dalle e-ink mate, très fin grain de microcapsules).
struct EInkPane: View {
    let decor: EInkDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack {
            if decor.grain {
                Rectangle()
                    .fill(ImagePaint(image: Image(nsImage: EInkTextures.slabGrain(dark: decor.dark))))
                    .clipShape(shape)
            }
        }
        .allowsHitTesting(false)
    }
}

/// Par-dessus le surlignage de la ligne choisie : vidéo inverse pure et mate, micro-grain discret pour
/// conserver la texture de l'encre sans aucune couleur ni flou.
struct EInkSelection: View {
    let decor: EInkDecor
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        if decor.grain {
            Rectangle()
                .fill(ImagePaint(image: Image(nsImage: EInkTextures.slabGrain(dark: !decor.dark))))
                .opacity(0.65)
                .clipShape(shape)
                .allowsHitTesting(false)
        }
    }
}

/// Séparateur mat : filet fin sur la séparation verticale (aperçu presse-papiers) ; les séparateurs
/// d'en-tête et de pied restent nus puisque le panneau intérieur est déjà serti dans le cadre.
struct EInkDivider: View {
    let decor: EInkDecor
    let vertical: Bool
    let role: StyleDivider.Role

    var body: some View {
        if vertical {
            Rectangle()
                .fill(decor.ink.opacity(decor.dark ? 0.24 : 0.22))
                .allowsHitTesting(false)
        }
    }
}

/// Pastille d'un symbole (recherche web, presse-papiers, réglages…) :
/// au repos, vignette encadrée sur trame de Bayer 4×4 ; choisie, inversée en positif pour rester parfaitement lisible.
struct EInkTile: View {
    let decor: EInkDecor
    let name: String
    let tint: Color
    let selected: Bool

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let compact = side < 16
            let corner: CGFloat = compact ? 2 : 3
            let shape = RoundedRectangle(cornerRadius: corner, style: .continuous)

            ZStack {
                if selected {
                    // Sur la ligne en vidéo inverse : pastille claire (Jour) ou sombre (Nuit) à fort contraste.
                    shape.fill(decor.pane)
                } else {
                    shape.fill(decor.pane)
                    if decor.ditherTiles && !compact {
                        Rectangle()
                            .fill(ImagePaint(image: Image(nsImage: EInkTextures.bayerTile(dark: decor.dark))))
                            .clipShape(shape)
                    } else {
                        shape.fill(decor.ink.opacity(0.07))
                    }
                    shape.strokeBorder(decor.border.opacity(decor.dark ? 0.85 : 0.72), lineWidth: compact ? 0.75 : 1)
                }

                Image(systemName: name)
                    .font(.system(size: max(8, side * 0.48), weight: selected ? .semibold : .medium))
                    .foregroundStyle(decor.ink)
            }
            .frame(width: side, height: side)
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
        .padding(1)
    }
}

/// Anneau du logo : trait d'encre mat et net.
struct EInkMarkRing: View {
    let progress: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        MarkRing()
            .trim(from: 0, to: progress)
            .stroke(ink, style: StrokeStyle(lineWidth: line, lineCap: .butt))
    }
}

/// Point du logo : pastille d'encre pleine, sans flou ni halo.
struct EInkMarkDot: View {
    let radius: CGFloat
    let line: CGFloat
    let ink: Color
    let dot: Color

    var body: some View {
        Circle()
            .fill(dot)
            .frame(width: 2 * radius, height: 2 * radius)
    }
}

/// Réglages › Apparence, quand la peau E-Encre est choisie.
struct EInkSettings: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        Section {
            Picker("Variante", selection: $settings.einkMode) {
                ForEach(EInkMode.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Toggle("Grain de dalle", isOn: $settings.einkGrain)
            Toggle("Pastilles tramées (Bayer 4×4)", isOn: $settings.einkDitherTiles)
        } header: {
            Text("E-Encre")
        } footer: {
            Text("Dalle gris minéral froid le jour, éclairage frontal ambré la nuit. Sélection instantanée en vidéo inverse, sans couleur ni flou.")
        }
    }
}
