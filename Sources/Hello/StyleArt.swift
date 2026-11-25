import SwiftUI

/// Illustration d'un style pour la grille des réglages : un dessin à plat qui résume la matière et la signature
/// du style (une fougère pour le Cyanotype, des encodeurs pour Champ, une fêlure d'or pour la Laque…), plutôt
/// qu'une miniature du panneau qui ne pourrait jamais ressembler au vrai à cette taille.
struct StyleArt: View {
    let style: PanelStyle

    var body: some View {
        let t = style.tokens
        Canvas { ctx, size in
            let art = Art(ctx: ctx, size: size, t: t)
            switch style {
            case .glass: art.glass()
            case .atelier: art.atelier()
            case .glyph: art.glyph()
            case .phosphor: art.phosphor()
            case .paper: art.paper()
            case .brutal: art.brutal()
            case .cyanotype: art.cyanotype()
            case .field: art.field()
            case .swiss: art.swiss()
            case .platinum: art.platinum()
            case .eink: art.eink()
            case .lacquer: art.lacquer()
            case .riso: art.riso()
            }
        }
        .background { StyleCard.backdrop(style) }
        .allowsHitTesting(false)
    }
}

/// Les dessins eux-mêmes. Repère : la vignette (≈ 150 × 84 pt) ; tout est proportionnel à sa hauteur.
private struct Art {
    let ctx: GraphicsContext
    let size: CGSize
    let t: StyleTokens

    var w: CGFloat { size.width }
    var h: CGFloat { size.height }
    var u: CGFloat { h / 84 }
    var cx: CGFloat { w / 2 }

    /// Panneau schématique centré (rapport du vrai panneau).
    func panel(width: CGFloat = 96, height: CGFloat = 58, dx: CGFloat = 0, dy: CGFloat = 0) -> CGRect {
        CGRect(x: cx - width * u / 2 + dx * u, y: h / 2 - height * u / 2 + dy * u, width: width * u, height: height * u)
    }

    func rr(_ r: CGRect, _ radius: CGFloat) -> Path {
        Path(roundedRect: r, cornerRadius: radius * u, style: .continuous)
    }

    func fill(_ p: Path, _ c: Color) { ctx.fill(p, with: .color(c)) }
    func stroke(_ p: Path, _ c: Color, _ lw: CGFloat) { ctx.stroke(p, with: .color(c), lineWidth: lw * u) }

    func line(_ a: CGPoint, _ b: CGPoint) -> Path {
        var p = Path(); p.move(to: a); p.addLine(to: b); return p
    }

    func text(_ s: String, _ font: Font, _ c: Color, at p: CGPoint, anchor: UnitPoint = .leading) {
        ctx.draw(Text(s).font(font).foregroundColor(c), at: p, anchor: anchor)
    }

    /// Barres de « lignes de texte » : la première choisie.
    func rows(in r: CGRect, count: Int = 3, ink: Color, selection: Color?, selectionInk: Color? = nil,
              radius: CGFloat = 3, inset: CGFloat = 6) {
        let rowH = 10 * u, gap = 3 * u
        for i in 0..<count {
            let y = r.minY + inset * u + CGFloat(i) * (rowH + gap)
            let rowRect = CGRect(x: r.minX + 4 * u, y: y, width: r.width - 8 * u, height: rowH)
            if i == 0, let selection { fill(rr(rowRect, radius), selection) }
            let lineInk = i == 0 ? (selectionInk ?? ink) : ink
            let len = [0.55, 0.72, 0.42][i % 3]
            fill(rr(CGRect(x: rowRect.minX + 5 * u, y: rowRect.midY - 1.5 * u,
                           width: (rowRect.width - 10 * u) * len, height: 3 * u), 1.5), lineInk.opacity(i == 0 ? 1 : 0.55))
        }
    }

    // MARK: Styles

    func glass() {
        ctx.drawLayer { layer in
            layer.addFilter(.blur(radius: 14 * u))
            layer.fill(Path(ellipseIn: CGRect(x: w * 0.12, y: h * 0.1, width: 46 * u, height: 46 * u)), with: .color(Color(hex: "#FF5FA2")))
            layer.fill(Path(ellipseIn: CGRect(x: w * 0.58, y: h * 0.35, width: 52 * u, height: 52 * u)), with: .color(Color(hex: "#39D2FF")))
        }
        let r = panel()
        fill(rr(r, 14), .white.opacity(0.16))
        ctx.stroke(rr(r, 14), with: .linearGradient(
            Gradient(colors: [Color(hex: "#FF8BD0"), Color(hex: "#FFE27A"), Color(hex: "#7CF2FF"), .white.opacity(0.2)]),
            startPoint: CGPoint(x: r.minX, y: r.minY), endPoint: CGPoint(x: r.maxX, y: r.maxY)), lineWidth: 1.4 * u)
        // Reflet spéculaire.
        var glint = Path()
        glint.addArc(center: CGPoint(x: r.minX + 14 * u, y: r.minY + 14 * u), radius: 9 * u,
                     startAngle: .degrees(190), endAngle: .degrees(260), clockwise: false)
        stroke(glint, .white.opacity(0.85), 1.6)
        fill(rr(CGRect(x: r.minX + 10 * u, y: r.minY + 9 * u, width: r.width - 20 * u, height: 8 * u), 4), .white.opacity(0.32))
        rows(in: r.offsetBy(dx: 0, dy: 13 * u), count: 2, ink: .white, selection: .white.opacity(0.22), radius: 5)
    }

    func atelier() {
        let colors = AtelierPalette.current
        let r = panel(width: 104, height: 62, dx: -10)
        fill(rr(r, 16), t.dark ? Color(hex: "#1D1B20") : Color(hex: "#FEF7FF"))
        // Barre de recherche en pilule.
        fill(Path(roundedRect: CGRect(x: r.minX + 6 * u, y: r.minY + 6 * u, width: r.width - 12 * u, height: 11 * u),
                  cornerRadius: 5.5 * u), colors.primary.opacity(0.18))
        // Liste segmentée.
        for i in 0..<3 {
            let y = r.minY + 21 * u + CGFloat(i) * 12 * u
            let seg = CGRect(x: r.minX + 6 * u, y: y, width: r.width - 12 * u, height: 10.5 * u)
            fill(rr(seg, i == 0 ? 5 : 2), i == 0 ? colors.primary : colors.primary.opacity(0.1))
        }
        // Cookie Material qui déborde.
        let c = CGRect(x: r.maxX - 12 * u, y: r.minY - 8 * u, width: 34 * u, height: 34 * u)
        fill(CookieShape(lobes: 9, depth: 0.12).path(in: c), colors.secondary == colors.primary ? .orange : colors.primary.opacity(0.9))
        fill(Path(ellipseIn: c.insetBy(dx: 11 * u, dy: 11 * u)), t.dark ? .black.opacity(0.35) : .white.opacity(0.9))
    }

    func glyph() {
        fill(Path(CGRect(origin: .zero, size: size)), Color(hex: "#0E0D0C"))
        let accent = t.accent
        // Logo en points : anneau ouvert de pixels + point d'accent plein.
        let center = CGPoint(x: w * 0.34, y: h / 2)
        for i in 0..<22 {
            let a = Double(i) / 22 * 2 * .pi
            guard a < 1.75 * .pi else { continue }
            let p = CGPoint(x: center.x + cos(a - .pi / 2) * 20 * u, y: center.y + sin(a - .pi / 2) * 20 * u)
            fill(Path(ellipseIn: CGRect(x: p.x - 1.7 * u, y: p.y - 1.7 * u, width: 3.4 * u, height: 3.4 * u)), .white.opacity(0.92))
        }
        fill(Path(ellipseIn: CGRect(x: center.x + 9 * u, y: center.y - 23 * u, width: 8 * u, height: 8 * u)), accent)
        // Lignes en chasse fixe (points), la première inversée.
        for i in 0..<3 {
            let y = h * 0.32 + CGFloat(i) * 12 * u
            let x0 = w * 0.58
            if i == 0 { fill(Path(CGRect(x: x0 - 3 * u, y: y - 4.5 * u, width: w * 0.36, height: 9 * u)), .white) }
            for j in 0..<Int((w * 0.3) / (4 * u)) where (j % 7) != 5 {
                fill(Path(CGRect(x: x0 + CGFloat(j) * 4 * u, y: y - 1.2 * u, width: 2.4 * u, height: 2.4 * u)),
                     i == 0 ? .black : .white.opacity(0.5))
            }
        }
    }

    func phosphor() {
        let ink = t.accent
        fill(Path(CGRect(origin: .zero, size: size)), Color(hex: "#050906"))
        // Écran bombé.
        let screen = CGRect(x: 10 * u, y: 8 * u, width: w - 20 * u, height: h - 16 * u)
        fill(rr(screen, 12), ink.opacity(0.07))
        stroke(rr(screen, 12), ink.opacity(0.35), 1)
        var y = screen.minY
        while y < screen.maxY { fill(Path(CGRect(x: screen.minX, y: y, width: screen.width, height: 0.8 * u)), .black.opacity(0.45)); y += 2.4 * u }
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: ink.opacity(0.9), radius: 5 * u))
            layer.draw(Text("> saf").font(.system(size: 17 * u, weight: .bold, design: .monospaced)).foregroundColor(ink),
                       at: CGPoint(x: screen.minX + 12 * u, y: screen.midY - 6 * u), anchor: .leading)
            layer.fill(Path(CGRect(x: screen.minX + 74 * u, y: screen.midY - 14 * u, width: 9 * u, height: 16 * u)), with: .color(ink))
            layer.fill(Path(CGRect(x: screen.minX + 12 * u, y: screen.midY + 10 * u, width: 60 * u, height: 2.4 * u)), with: .color(ink.opacity(0.6)))
            layer.fill(Path(CGRect(x: screen.minX + 12 * u, y: screen.midY + 17 * u, width: 40 * u, height: 2.4 * u)), with: .color(ink.opacity(0.4)))
        }
    }

    func paper() {
        let sheet = t.dark ? Color(hex: "#2A2622") : Color(hex: "#FBF6EC")
        let ink = t.dark ? Color(hex: "#EDE3D0") : Color(hex: "#2B2118")
        var g = ctx
        g.translateBy(x: cx, y: h / 2)
        g.rotate(by: .degrees(-4))
        let r = CGRect(x: -48 * u, y: -32 * u, width: 96 * u, height: 64 * u)
        g.fill(Path(r).offsetBy(dx: 2 * u, dy: 3 * u), with: .color(.black.opacity(0.12)))
        var body = Path()
        body.move(to: CGPoint(x: r.minX, y: r.minY))
        body.addLine(to: CGPoint(x: r.maxX - 14 * u, y: r.minY))
        body.addLine(to: CGPoint(x: r.maxX, y: r.minY + 14 * u))
        body.addLine(to: CGPoint(x: r.maxX, y: r.maxY))
        body.addLine(to: CGPoint(x: r.minX, y: r.maxY))
        body.closeSubpath()
        g.fill(body, with: .color(sheet))
        var fold = Path()
        fold.move(to: CGPoint(x: r.maxX - 14 * u, y: r.minY))
        fold.addLine(to: CGPoint(x: r.maxX - 14 * u, y: r.minY + 14 * u))
        fold.addLine(to: CGPoint(x: r.maxX, y: r.minY + 14 * u))
        fold.closeSubpath()
        g.fill(fold, with: .color(ink.opacity(0.12)))
        g.draw(Text("Aa").font(.custom("Georgia-Italic", size: 24 * u)).foregroundColor(ink),
               at: CGPoint(x: r.minX + 10 * u, y: r.minY + 20 * u), anchor: .leading)
        // Trait d'encre tracé à la main.
        var stroke = Path()
        stroke.move(to: CGPoint(x: r.minX + 10 * u, y: r.minY + 36 * u))
        stroke.addCurve(to: CGPoint(x: r.minX + 74 * u, y: r.minY + 34 * u),
                        control1: CGPoint(x: r.minX + 30 * u, y: r.minY + 40 * u),
                        control2: CGPoint(x: r.minX + 52 * u, y: r.minY + 30 * u))
        g.stroke(stroke, with: .color(t.accent), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round))
        for i in 0..<2 {
            g.fill(Path(CGRect(x: r.minX + 10 * u, y: r.minY + (46 + CGFloat(i) * 7) * u, width: (i == 0 ? 60 : 42) * u, height: 2 * u)),
                   with: .color(ink.opacity(0.35)))
        }
    }

    func brutal() {
        let r = panel(width: 92, height: 56, dx: -3, dy: -3)
        fill(Path(r.offsetBy(dx: 6 * u, dy: 6 * u)), .black)
        fill(Path(r), .white)
        stroke(Path(r), .black, 2.4)
        let sel = CGRect(x: r.minX + 6 * u, y: r.minY + 16 * u, width: r.width - 12 * u, height: 12 * u)
        fill(Path(sel), Color(hex: "#FFD400"))
        stroke(Path(sel), .black, 1.8)
        fill(Path(CGRect(x: r.minX + 8 * u, y: r.minY + 6 * u, width: 40 * u, height: 4 * u)), .black)
        for i in 0..<2 {
            fill(Path(CGRect(x: r.minX + 10 * u, y: r.minY + (35 + CGFloat(i) * 9) * u, width: (i == 0 ? 50 : 34) * u, height: 3 * u)), .black)
        }
        // Pastille autocollante.
        let star = CGRect(x: r.maxX - 16 * u, y: r.minY - 10 * u, width: 24 * u, height: 24 * u)
        fill(Path(ellipseIn: star), Color(hex: "#FF4FA3"))
        stroke(Path(ellipseIn: star), .black, 1.8)
    }

    func cyanotype() {
        let blue = t.dark ? Color(hex: "#0A1A33") : Color(hex: "#1F4E8C")
        let print = CGRect(x: 8 * u, y: 6 * u, width: w - 16 * u, height: h - 12 * u)
        fill(Path(CGRect(origin: .zero, size: size)), t.dark ? Color(hex: "#13161B") : Color(hex: "#F3EEE2"))
        // Lavis au pinceau : bords irréguliers.
        var wash = Path()
        let steps = 40
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)
            let x = print.minX + print.width * f
            let y = print.minY + sin(f * 23) * 1.6 * u + cos(f * 51) * 1.1 * u
            if i == 0 { wash.move(to: CGPoint(x: x, y: y)) } else { wash.addLine(to: CGPoint(x: x, y: y)) }
        }
        for i in 0...steps {
            let f = CGFloat(i) / CGFloat(steps)
            let x = print.maxX - print.width * f
            let y = print.maxY + sin(f * 19 + 1) * 1.6 * u + cos(f * 43) * 1.2 * u
            wash.addLine(to: CGPoint(x: x, y: y))
        }
        wash.closeSubpath()
        fill(wash, blue)
        // Fougère en photogramme.
        let paperWhite = Color(hex: "#EAF3FA")
        let base = CGPoint(x: w * 0.3, y: print.maxY - 4 * u)
        let tip = CGPoint(x: w * 0.72, y: print.minY + 8 * u)
        var stem = Path()
        stem.move(to: base)
        stem.addQuadCurve(to: tip, control: CGPoint(x: w * 0.42, y: print.minY + 10 * u))
        stroke(stem, paperWhite.opacity(0.9), 1.2)
        let control = CGPoint(x: w * 0.42, y: print.minY + 10 * u)
        for i in 1..<15 {
            let f = CGFloat(i) / 15
            let p = quad(base, control, tip, f)
            let q = quad(base, control, tip, min(f + 0.01, 1))
            // Tangente et normale de la tige : les folioles partent de chaque côté, inclinées vers la pointe.
            let len0 = max(hypot(q.x - p.x, q.y - p.y), 0.001)
            let tx = (q.x - p.x) / len0, ty = (q.y - p.y) / len0
            let len = (1 - f) * 16 * u + 3.5 * u
            for side: CGFloat in [-1, 1] {
                let nx = -ty * side, ny = tx * side
                let end = CGPoint(x: p.x + (nx * 0.85 + tx * 0.5) * len, y: p.y + (ny * 0.85 + ty * 0.5) * len)
                let ctrl = CGPoint(x: p.x + (nx * 0.6 + tx * 0.05) * len, y: p.y + (ny * 0.6 + ty * 0.05) * len)
                var leaf = Path()
                leaf.move(to: p)
                leaf.addQuadCurve(to: end, control: ctrl)
                ctx.stroke(leaf, with: .color(paperWhite.opacity(0.85)),
                           style: StrokeStyle(lineWidth: 2.4 * u * (1 - f * 0.5), lineCap: .round))
            }
        }
    }

    private func quad(_ a: CGPoint, _ c: CGPoint, _ b: CGPoint, _ t: CGFloat) -> CGPoint {
        let m = 1 - t
        return CGPoint(x: m * m * a.x + 2 * m * t * c.x + t * t * b.x, y: m * m * a.y + 2 * m * t * c.y + t * t * b.y)
    }

    func field() {
        let frame = t.dark ? Color(hex: "#1B1C1E") : Color(hex: "#CED0D1")
        let plate = t.dark ? Color(hex: "#2A2B2E") : Color(hex: "#F6F5F1")
        fill(Path(CGRect(origin: .zero, size: size)), frame)
        let r = CGRect(x: 10 * u, y: 10 * u, width: w - 20 * u, height: 34 * u)
        fill(rr(r, 6), plate)
        stroke(rr(r, 6), .black.opacity(0.35), 0.8)
        // Échelle pointillée.
        var x = r.minX + 4 * u
        var i = 0
        while x < r.maxX - 4 * u {
            let d: CGFloat = i % 5 == 0 ? 2.2 : 1.4
            fill(Path(ellipseIn: CGRect(x: x, y: r.maxY + 5 * u, width: d * u, height: d * u)),
                 (t.dark ? Color.white : Color.black).opacity(i % 5 == 0 ? 0.55 : 0.3))
            x += 4.5 * u; i += 1
        }
        // Quatre encodeurs.
        let colors = [Color(hex: "#23315C"), Color(hex: "#C7A37B"), Color(hex: "#A6A8AA"), Color(hex: "#F2541B")]
        let spacing = (w - 20 * u) / 4
        for (k, c) in colors.enumerated() {
            let center = CGPoint(x: 10 * u + spacing * (CGFloat(k) + 0.5), y: h - 18 * u)
            let d = 18 * u
            fill(Path(ellipseIn: CGRect(x: center.x - d / 2, y: center.y - d / 2 + 1.2 * u, width: d, height: d)), .black.opacity(0.25))
            fill(Path(ellipseIn: CGRect(x: center.x - d / 2, y: center.y - d / 2, width: d, height: d)), c)
            let angle = Double(k) * 0.9 - 2.2
            stroke(line(center, CGPoint(x: center.x + cos(angle) * 6.5 * u, y: center.y + sin(angle) * 6.5 * u)),
                   .white.opacity(0.9), 1.6)
        }
        // Touche choisie.
        fill(rr(CGRect(x: r.minX + 6 * u, y: r.minY + 6 * u, width: 44 * u, height: 9 * u), 3), t.accent)
        fill(rr(CGRect(x: r.minX + 6 * u, y: r.minY + 19 * u, width: 64 * u, height: 3 * u), 1.5), (t.dark ? Color.white : .black).opacity(0.3))
    }

    func swiss() {
        let bg = t.dark ? Color(hex: "#0D0D0D") : .white
        let ink = t.dark ? Color.white : .black
        let red = t.accent
        fill(Path(CGRect(origin: .zero, size: size)), bg)
        // Grille fine.
        for gx in stride(from: 14 * u, to: w, by: 22 * u) {
            fill(Path(CGRect(x: gx, y: 0, width: 0.5 * u, height: h)), ink.opacity(0.1))
        }
        // Horloge de gare.
        let c = CGPoint(x: 26 * u, y: 28 * u)
        stroke(Path(ellipseIn: CGRect(x: c.x - 15 * u, y: c.y - 15 * u, width: 30 * u, height: 30 * u)), ink, 2.2)
        for k in 0..<12 {
            let a = Double(k) / 12 * 2 * .pi
            stroke(line(CGPoint(x: c.x + cos(a) * 10.5 * u, y: c.y + sin(a) * 10.5 * u),
                        CGPoint(x: c.x + cos(a) * 13 * u, y: c.y + sin(a) * 13 * u)), ink, 1.2)
        }
        stroke(line(c, CGPoint(x: c.x + 7 * u, y: c.y - 6 * u)), ink, 2)
        stroke(line(c, CGPoint(x: c.x - 2 * u, y: c.y - 11 * u)), red, 1)
        fill(Path(ellipseIn: CGRect(x: c.x - 2 * u - 2.2 * u, y: c.y - 11 * u - 2.2 * u, width: 4.4 * u, height: 4.4 * u)), red)
        text("saf", .system(size: 20 * u, weight: .bold), ink, at: CGPoint(x: 50 * u, y: 28 * u))
        // Bandeau de départ.
        fill(Path(CGRect(x: 0, y: 52 * u, width: w, height: 13 * u)), ink)
        fill(Path(CGRect(x: 8 * u, y: 57 * u, width: 50 * u, height: 3 * u)), bg)
        fill(Path(ellipseIn: CGRect(x: w - 16 * u, y: 55 * u, width: 7 * u, height: 7 * u)), red)
        fill(Path(CGRect(x: 14 * u, y: 46 * u, width: 22 * u, height: 2 * u)), red)
    }

    func platinum() {
        let grey = t.dark ? Color(hex: "#5A5F6B") : Color(hex: "#DDDDDD")
        let win = panel(width: 92, height: 58, dx: 6, dy: 4)
        // Zoom Rects qui grandissent vers la fenêtre.
        for k in 0..<3 {
            let s = 0.3 + 0.2 * CGFloat(k)
            let r = CGRect(x: win.midX - win.width * s / 2 - (2 - CGFloat(k)) * 14 * u,
                           y: win.midY - win.height * s / 2 - (2 - CGFloat(k)) * 8 * u,
                           width: win.width * s, height: win.height * s)
            stroke(Path(r), .white.opacity(0.4 + 0.2 * Double(k)), 0.8)
        }
        fill(Path(win.offsetBy(dx: 2 * u, dy: 2 * u)), .black.opacity(0.5))
        fill(Path(win), grey)
        stroke(Path(win), .black, 1)
        // Barre de titre rayée.
        let bar = CGRect(x: win.minX + 3 * u, y: win.minY + 3 * u, width: win.width - 6 * u, height: 10 * u)
        var y = bar.minY
        while y < bar.maxY {
            fill(Path(CGRect(x: bar.minX, y: y, width: bar.width, height: 0.9 * u)), (t.dark ? Color.black : Color(hex: "#9A9A9A")).opacity(0.8))
            y += 2 * u
        }
        fill(Path(CGRect(x: bar.minX + 4 * u, y: bar.minY + 1.5 * u, width: 7 * u, height: 7 * u)), grey)
        stroke(Path(CGRect(x: bar.minX + 4 * u, y: bar.minY + 1.5 * u, width: 7 * u, height: 7 * u)), .black, 0.8)
        // Liste en creux.
        let well = CGRect(x: win.minX + 5 * u, y: bar.maxY + 4 * u, width: win.width - 10 * u, height: win.maxY - bar.maxY - 9 * u)
        fill(Path(well), t.dark ? Color(hex: "#2A2D33") : .white)
        stroke(line(CGPoint(x: well.minX, y: well.maxY), CGPoint(x: well.minX, y: well.minY)), .black.opacity(0.6), 1)
        stroke(line(CGPoint(x: well.minX, y: well.minY), CGPoint(x: well.maxX, y: well.minY)), .black.opacity(0.6), 1)
        rows(in: well.insetBy(dx: -2 * u, dy: -4 * u), count: 2, ink: t.dark ? .white : .black,
             selection: t.selectionFill, selectionInk: t.dark ? .white : .black, radius: 0)
    }

    func eink() {
        let bezel = t.dark ? Color(hex: "#1D1C1A") : Color(hex: "#3B3C3A")
        let screen = t.dark ? Color(hex: "#151513") : Color(hex: "#E6E6E1")
        let ink = t.dark ? Color(hex: "#E5DEC9") : Color(hex: "#1A1A18")
        let device = CGRect(x: cx - 34 * u, y: 5 * u, width: 68 * u, height: h - 10 * u)
        fill(rr(device, 7), bezel)
        let s = device.insetBy(dx: 6 * u, dy: 7 * u)
        fill(Path(s), screen)
        let lines: [CGFloat] = [0.8, 0.95, 0.6, 0.9, 0.7, 0.85]
        for (k, f) in lines.enumerated() {
            let y = s.minY + 5 * u + CGFloat(k) * 8.5 * u
            if k == 1 {
                fill(Path(CGRect(x: s.minX, y: y - 3 * u, width: s.width, height: 8 * u)), ink)
                fill(Path(CGRect(x: s.minX + 4 * u, y: y, width: (s.width - 8 * u) * f, height: 2 * u)), screen)
            } else {
                fill(Path(CGRect(x: s.minX + 4 * u, y: y, width: (s.width - 8 * u) * f, height: 2 * u)), ink.opacity(0.75))
            }
        }
        // Grain de dalle dessiné à la main (points).
        var seed: UInt64 = 7
        for _ in 0..<26 {
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            let px = s.minX + CGFloat((seed >> 20) % 1000) / 1000 * s.width
            let py = s.minY + CGFloat((seed >> 40) % 1000) / 1000 * s.height
            fill(Path(CGRect(x: px, y: py, width: 0.8 * u, height: 0.8 * u)), ink.opacity(0.35))
        }
    }

    func lacquer() {
        let base: Color, gold = Color(hex: "#D9B25F")
        switch AppSettings.shared.lacquerMode {
        case .porcelain: base = Color(hex: "#F1EEE6")
        case .cinnabar: base = Color(hex: "#7A1E14")
        default: base = t.dark ? Color(hex: "#120E0B") : Color(hex: "#F1EEE6")
        }
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [base.opacity(0.9), base]), startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        // Lustre.
        ctx.fill(Path(CGRect(origin: .zero, size: size)), with: .linearGradient(
            Gradient(colors: [.white.opacity(0.10), .clear, .black.opacity(0.18)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: h)))
        // Fêlure kintsugi.
        let pts: [CGPoint] = [CGPoint(x: -2, y: 0.62), CGPoint(x: 0.22, y: 0.55), CGPoint(x: 0.38, y: 0.66),
                              CGPoint(x: 0.55, y: 0.48), CGPoint(x: 0.71, y: 0.52), CGPoint(x: 0.86, y: 0.34), CGPoint(x: 1.05, y: 0.3)]
        var crack = Path()
        for (k, p) in pts.enumerated() {
            let q = CGPoint(x: max(p.x, 0) * w, y: p.y * h)
            if k == 0 { crack.move(to: CGPoint(x: 0, y: q.y)) } else { crack.addLine(to: q) }
        }
        var branch = Path()
        branch.move(to: CGPoint(x: 0.55 * w, y: 0.48 * h))
        branch.addLine(to: CGPoint(x: 0.6 * w, y: 0.7 * h))
        branch.addLine(to: CGPoint(x: 0.66 * w, y: 0.84 * h))
        ctx.drawLayer { layer in
            layer.addFilter(.shadow(color: gold.opacity(0.8), radius: 3 * u))
            layer.stroke(crack, with: .color(gold), style: StrokeStyle(lineWidth: 2 * u, lineCap: .round, lineJoin: .round))
            layer.stroke(branch, with: .color(gold), style: StrokeStyle(lineWidth: 1.1 * u, lineCap: .round, lineJoin: .round))
        }
        // Sceau hanko.
        let seal = CGRect(x: w - 22 * u, y: h - 22 * u, width: 12 * u, height: 12 * u)
        fill(rr(seal, 2), Color(hex: "#C8371F"))
        stroke(rr(seal.insetBy(dx: 2 * u, dy: 2 * u), 1), .white.opacity(0.7), 0.7)
    }

    func riso() {
        let paper = t.dark ? Color(hex: "#25283A") : Color(hex: "#F1ECE0")
        let blue = RisoPalette.blue(dark: t.dark)
        let pink = RisoPalette.pink(dark: t.dark)
        let blend: GraphicsContext.BlendMode = t.dark ? .screen : .multiply
        fill(Path(CGRect(origin: .zero, size: size)), paper)
        var g = ctx
        g.blendMode = blend
        // Passe rose tramée, décalée.
        let disc = CGRect(x: w * 0.12, y: h / 2 - 24 * u, width: 44 * u, height: 44 * u)
        g.drawLayer { layer in
            layer.clip(to: Path(ellipseIn: disc.offsetBy(dx: 18 * u, dy: 4 * u)))
            var y = disc.minY
            var row = 0
            while y < disc.maxY + 8 * u {
                var x = disc.minX + 18 * u + (row % 2 == 0 ? 0 : 1.8 * u)
                while x < disc.maxX + 20 * u {
                    layer.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 2.4 * u, height: 2.4 * u)), with: .color(pink))
                    x += 3.6 * u
                }
                y += 3 * u; row += 1
            }
        }
        g.fill(Path(ellipseIn: disc), with: .color(blue.opacity(0.9)))
        // Texte en deux passes mal calées.
        g.draw(Text("saf").font(.system(size: 19 * u, weight: .black)).foregroundColor(pink),
               at: CGPoint(x: w * 0.76 + 2 * u, y: h * 0.5 + 1.5 * u), anchor: .center)
        g.draw(Text("saf").font(.system(size: 19 * u, weight: .black)).foregroundColor(blue),
               at: CGPoint(x: w * 0.76, y: h * 0.5), anchor: .center)
    }
}
