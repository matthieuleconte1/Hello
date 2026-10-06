// Génère Resources/AppIcon.icns : swift Scripts/make-icon.swift && iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
// Le logo de Hello (anneau ouvert et point, peau « Verre ») sur une icône macOS sombre.
// (Icon Composer demande Xcode ; ici l'effet verre est dessiné : lueur, reflets, ombre.)
import AppKit
import CoreImage

let size = 1024
let full = CGRect(x: 0, y: 0, width: size, height: size)
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ci = CIContext(options: [.workingColorSpace: space])

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                           CGFloat(hex & 0xFF) / 255, a])!
}

func canvas(_ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    draw(ctx)
    return ctx.makeImage()!
}

func blurred(_ image: CGImage, _ radius: Double) -> CGImage {
    let input = CIImage(cgImage: image).clampedToExtent()
    return ci.createCGImage(input.applyingGaussianBlur(sigma: radius).cropped(to: full), from: full)!
}

func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}

/// Forme d'icône macOS (superellipse, coins continus) sur la grille standard 824/1024.
func squircle(_ rect: CGRect, n: Double = 5) -> CGPath {
    let path = CGMutablePath()
    let a = rect.width / 2, b = rect.height / 2
    for i in 0...720 {
        let t = Double(i) / 720 * 2 * .pi
        let c = cos(t), s = sin(t)
        let x = pow(abs(c), 2 / n) * a * (c < 0 ? -1 : 1)
        let y = pow(abs(s), 2 / n) * b * (s < 0 ? -1 : 1)
        let p = CGPoint(x: rect.midX + x, y: rect.midY + y)
        i == 0 ? path.move(to: p) : path.addLine(to: p)
    }
    path.closeSubpath()
    return path
}

let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = squircle(body)
let center = CGPoint(x: 512, y: 512)

// Le logo sur sa grille de 200, agrandi : l'anneau fait environ les deux tiers de l'icône.
let scale: CGFloat = 3.6
let radius = 62 * scale
let line = 26 * scale
// Repère CoreGraphics (y vers le haut) : l'anneau part à 12,7° et tourne dans le sens horaire sur 295,4°.
let ringPath: CGPath = {
    let p = CGMutablePath()
    p.addArc(center: center, radius: radius, startAngle: 12.7 * .pi / 180, endAngle: -282.7 * .pi / 180, clockwise: true)
    return p
}()
let ringShape = ringPath.copy(strokingWithWidth: line, lineCap: .round, lineJoin: .round, miterLimit: 10)
let dotCenter = CGPoint(x: 512 + (143.84 - 100) * scale, y: 512 + (100 - 56.16) * scale)
let dotRadius = 13 * scale
let dotRect = CGRect(x: dotCenter.x - dotRadius, y: dotCenter.y - dotRadius, width: 2 * dotRadius, height: 2 * dotRadius)

// Dégradé du reflet : violet en bas à gauche, rose, orange, pêche en haut à droite.
let markGradient = gradient([rgb(0x5B4CFA), rgb(0xED5CBF), rgb(0xFFA866), rgb(0xFFE9CF)], [0, 0.45, 0.8, 1])
let gradientStart = CGPoint(x: 512 - 300, y: 512 - 300)
let gradientEnd = CGPoint(x: 512 + 300, y: 512 + 300)

let ring = canvas { ctx in
    ctx.addPath(ringShape)
    ctx.clip()
    ctx.drawLinearGradient(markGradient, start: gradientStart, end: gradientEnd, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}

let dot = canvas { ctx in
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: dotRect)
}

let icon = canvas { ctx in
    // Ombre de l'icône entière.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: rgb(0x000000, 0.4))
    ctx.addPath(bodyPath)
    ctx.setFillColor(rgb(0x1A1824))
    ctx.fillPath()
    ctx.restoreGState()

    // Fond : graphite profond, éclairé par le haut.
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0x34313F), rgb(0x16141C), rgb(0x0C0B10)], [0, 0.55, 1]),
                           start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
    ctx.drawRadialGradient(gradient([rgb(0xFFFFFF, 0.10), rgb(0xFFFFFF, 0)], [0, 1]),
                           startCenter: CGPoint(x: 300, y: 860), startRadius: 0,
                           endCenter: CGPoint(x: 300, y: 860), endRadius: 620, options: [])

    // Lueur du halo sous l'anneau et autour du point.
    ctx.setAlpha(0.65)
    ctx.draw(blurred(ring, 34), in: full)
    ctx.setAlpha(0.5)
    ctx.draw(blurred(dot, 26), in: full)
    ctx.setAlpha(1)

    // L'anneau avec son ombre portée, puis son volume de verre : clair en haut, plus sombre en bas.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 22, color: rgb(0x000000, 0.45))
    ctx.draw(ring, in: full)
    ctx.restoreGState()
    ctx.saveGState()
    ctx.addPath(ringShape)
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0xFFFFFF, 0.34), rgb(0xFFFFFF, 0.04), rgb(0x2A0A40, 0.18)], [0, 0.5, 1]),
                           start: CGPoint(x: 0, y: 512 + radius + line / 2), end: CGPoint(x: 0, y: 512 - radius - line / 2), options: [])
    // Arête spéculaire le long du bord extérieur, en haut à gauche.
    let rim = CGMutablePath()
    rim.addArc(center: center, radius: radius + line / 2 - 7, startAngle: 108 * .pi / 180, endAngle: 205 * .pi / 180, clockwise: false)
    ctx.addPath(rim)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.75))
    ctx.setLineWidth(7)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.restoreGState()

    // Le point : blanc, légèrement bombé.
    ctx.saveGState()
    ctx.addEllipse(in: dotRect)
    ctx.clip()
    ctx.drawRadialGradient(gradient([rgb(0xFFFFFF), rgb(0xF1ECFF)], [0, 1]),
                           startCenter: CGPoint(x: dotCenter.x - dotRadius * 0.3, y: dotCenter.y + dotRadius * 0.35), startRadius: 0,
                           endCenter: dotCenter, endRadius: dotRadius, options: [])
    ctx.restoreGState()

    // Liseré du squircle : lumineux en haut, plus discret en bas.
    ctx.addPath(bodyPath)
    ctx.setLineWidth(5)
    ctx.replacePathWithStrokedPath()
    ctx.clip()
    ctx.drawLinearGradient(gradient([rgb(0xFFFFFF, 0.35), rgb(0xFFFFFF, 0.04), rgb(0xFFFFFF, 0.12)], [0, 0.55, 1]),
                           start: CGPoint(x: 0, y: 924), end: CGPoint(x: 0, y: 100), options: [])
    ctx.restoreGState()
}

let fm = FileManager.default
let iconset = URL(fileURLWithPath: "build/AppIcon.iconset")
try? fm.removeItem(at: iconset)
try! fm.createDirectory(at: iconset, withIntermediateDirectories: true)

func write(_ image: CGImage, px: Int, to url: URL) {
    let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.interpolationQuality = .high
    ctx.draw(image, in: CGRect(x: 0, y: 0, width: px, height: px))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: url)
}

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        write(icon, px: base * scale, to: iconset.appendingPathComponent(name))
    }
}
write(icon, px: 1024, to: URL(fileURLWithPath: "build/AppIcon-preview.png"))
