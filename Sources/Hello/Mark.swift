import AppKit
import SwiftUI

/// Le logo de Hello : un anneau ouvert en haut à droite, et un point dans l'ouverture.
/// Construit sur une grille de 200 : anneau de rayon 62 et d'épaisseur 26, point de diamètre 26.
enum MarkGeometry {
    static let ringRadius: CGFloat = 62 / 200
    static let stroke: CGFloat = 26 / 200
    static let dotRadius: CGFloat = 13 / 200
    static let dotCenter = CGPoint(x: 143.84 / 200, y: 56.16 / 200)
    /// L'anneau part juste après le point (-12,7°) et en fait le tour sur 295,4°.
    static let startDegrees: Double = -12.7
    static let spanDegrees: Double = 295.4

    /// Dégradé du Verre : celui du reflet multicolore.
    static let glassColors = [Color(hex: "#5B4CFA"), Color(hex: "#ED5CBF"), Color(hex: "#FFA866"), Color(hex: "#FFE9CF")]
}

/// La ligne médiane de l'anneau, à tracer avec `stroke` ; `trim` le dessine progressivement depuis le point.
struct MarkRing: Shape {
    func path(in rect: CGRect) -> Path {
        let side = min(rect.width, rect.height)
        var path = Path()
        // Repère SwiftUI (y vers le bas) : `clockwise: false` tourne dans le sens des aiguilles d'une montre à l'écran.
        path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: side * MarkGeometry.ringRadius,
                    startAngle: .degrees(MarkGeometry.startDegrees),
                    endAngle: .degrees(MarkGeometry.startDegrees + MarkGeometry.spanDegrees), clockwise: false)
        return path
    }
}

/// Le logo, dans la matière d'un style (les « cinq peaux »).
struct HelloMark: View {
    enum Skin {
        /// Verre : anneau dégradé, point blanc lumineux.
        case glass
        /// Une seule couleur (barre des menus, versions monochromes).
        case ink(Color)
        /// Atelier : anneau d'encre, point en cookie Material.
        case atelier(ring: Color, dot: Color)
        /// Phosphore : anneau vert, le point devient le curseur bloc.
        case phosphor(Color)
        /// Papier : anneau d'encre, point vermillon.
        case paper(ink: Color, dot: Color)
        /// Néo-brutal : anneau rose cerclé de noir, point jaune.
        case brutal(Color)
    }

    var skin: Skin
    /// Part de l'anneau tracée (0 à 1).
    var progress: CGFloat = 1
    /// Taille du point (0 à 1).
    var dotScale: CGFloat = 1

    var body: some View {
        GeometryReader { geo in
            let side = min(geo.size.width, geo.size.height)
            let line = side * MarkGeometry.stroke
            let r = side * MarkGeometry.dotRadius * dotScale
            let dot = CGPoint(x: side * MarkGeometry.dotCenter.x, y: side * MarkGeometry.dotCenter.y)
            ZStack {
                ring(line)
                point(r, line: line).position(dot)
            }
            .frame(width: side, height: side)
        }
        .aspectRatio(1, contentMode: .fit)
    }

    @ViewBuilder
    private func ring(_ line: CGFloat) -> some View {
        let trimmed = MarkRing().trim(from: 0, to: progress)
        let style = StrokeStyle(lineWidth: line, lineCap: .round)
        switch skin {
        case .glass:
            trimmed.stroke(LinearGradient(colors: MarkGeometry.glassColors,
                                          startPoint: UnitPoint(x: 0.12, y: 0.92), endPoint: UnitPoint(x: 0.9, y: 0.08)),
                           style: style)
        case .ink(let color), .atelier(let color, _), .paper(let color, _):
            trimmed.stroke(color, style: style)
        case .phosphor(let color):
            trimmed.stroke(color, style: style).shadow(color: color.opacity(0.6), radius: line * 0.5)
        case .brutal(let color):
            ZStack {
                trimmed.stroke(Color.black, style: StrokeStyle(lineWidth: line * 1.3, lineCap: .round))
                trimmed.stroke(color, style: style)
            }
        }
    }

    @ViewBuilder
    private func point(_ r: CGFloat, line: CGFloat) -> some View {
        switch skin {
        case .glass:
            Circle().fill(Color.white).frame(width: 2 * r, height: 2 * r)
                .shadow(color: Color.white.opacity(0.8), radius: r * 0.6)
        case .ink(let color):
            Circle().fill(color).frame(width: 2 * r, height: 2 * r)
        case .atelier(_, let dot):
            CookieShape(lobes: 9, depth: 0.16).fill(dot)
                .frame(width: 2.6 * r, height: 2.6 * r)
                .rotationEffect(.degrees(20))
        case .phosphor(let color):
            Rectangle().fill(color).frame(width: r * 1.08, height: 2 * r)
        case .paper(_, let dot):
            Circle().fill(dot).frame(width: 2 * r, height: 2 * r)
        case .brutal:
            Circle().fill(Color(hex: "#FFD84D"))
                .frame(width: 2 * r, height: 2 * r)
                .overlay(Circle().strokeBorder(Color.black, lineWidth: line * 0.3).padding(-line * 0.15))
        }
    }

    /// Icône de la barre des menus : anneau et point, en image « template » (elle suit le thème de la barre).
    static func templateImage(side: CGFloat = 18) -> NSImage {
        let image = NSImage(size: NSSize(width: side, height: side), flipped: false) { _ in
            let center = NSPoint(x: side / 2, y: side / 2)
            let ring = NSBezierPath()
            // Repère AppKit (y vers le haut) : mêmes angles, en miroir.
            ring.appendArc(withCenter: center, radius: side * MarkGeometry.ringRadius,
                           startAngle: -MarkGeometry.startDegrees,
                           endAngle: -(MarkGeometry.startDegrees + MarkGeometry.spanDegrees), clockwise: true)
            ring.lineWidth = side * MarkGeometry.stroke
            ring.lineCapStyle = .round
            NSColor.black.setStroke()
            ring.stroke()
            let r = side * MarkGeometry.dotRadius
            let dot = NSPoint(x: side * MarkGeometry.dotCenter.x, y: side * (1 - MarkGeometry.dotCenter.y))
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: dot.x - r, y: dot.y - r, width: 2 * r, height: 2 * r)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}

/// Le logo de la barre de recherche : à chaque ouverture, le point s'allume et l'anneau en part pour faire le tour.
struct AnimatedMark: View {
    struct Values {
        var progress: CGFloat = 1
        var dot: CGFloat = 1
    }

    let skin: HelloMark.Skin
    let trigger: Int

    var body: some View {
        if Motion.enabled {
            let t = 1 / Motion.speed
            Color.clear
                .keyframeAnimator(initialValue: Values(), trigger: trigger) { _, value in
                    HelloMark(skin: skin, progress: value.progress, dotScale: value.dot)
                } keyframes: { _ in
                    KeyframeTrack(\.dot) {
                        LinearKeyframe(0, duration: 0.001)
                        SpringKeyframe(1, duration: 0.3 * t, spring: .init(response: 0.26, dampingRatio: 0.55))
                    }
                    KeyframeTrack(\.progress) {
                        LinearKeyframe(0, duration: 0.001)
                        LinearKeyframe(0, duration: 0.1 * t)
                        SpringKeyframe(1, duration: 0.55 * t, spring: .init(response: 0.45, dampingRatio: 0.92))
                    }
                }
        } else {
            HelloMark(skin: skin)
        }
    }
}
