// Bannière du README : swift Scripts/make-banner.swift → docs/banner.png
import AppKit
import CoreImage

let width = 2560, height = 960
let full = CGRect(x: 0, y: 0, width: width, height: height)
let space = CGColorSpace(name: CGColorSpace.sRGB)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: space, components: [CGFloat((hex >> 16) & 0xFF) / 255, CGFloat((hex >> 8) & 0xFF) / 255,
                                           CGFloat(hex & 0xFF) / 255, a])!
}
func gradient(_ colors: [CGColor], _ locations: [CGFloat]) -> CGGradient {
    CGGradient(colorsSpace: space, colors: colors as CFArray, locations: locations)!
}
func layer(_ draw: (CGContext) -> Void) -> CGImage {
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(ctx)
    return ctx.makeImage()!
}
func blurred(_ image: CGImage, _ radius: Double) -> CGImage {
    let out = CIImage(cgImage: image).clampedToExtent().applyingGaussianBlur(sigma: radius).cropped(to: full)
    return CIContext().createCGImage(out, from: full)!
}

// Le logo sur sa grille de 200, posé à gauche.
let scale: CGFloat = 2.9
let center = CGPoint(x: 700, y: 480)
let ringPath = CGMutablePath()
ringPath.addArc(center: center, radius: 62 * scale, startAngle: 12.7 * .pi / 180, endAngle: -282.7 * .pi / 180, clockwise: true)
let ringShape = ringPath.copy(strokingWithWidth: 26 * scale, lineCap: .round, lineJoin: .round, miterLimit: 10)
let dotCenter = CGPoint(x: center.x + 43.84 * scale, y: center.y + 43.84 * scale)
let dotRect = CGRect(x: dotCenter.x - 13 * scale, y: dotCenter.y - 13 * scale, width: 26 * scale, height: 26 * scale)
let markGradient = gradient([rgb(0x5B4CFA), rgb(0xED5CBF), rgb(0xFFA866), rgb(0xFFE9CF)], [0, 0.45, 0.8, 1])

let ring = layer { ctx in
    ctx.addPath(ringShape)
    ctx.clip()
    ctx.drawLinearGradient(markGradient, start: CGPoint(x: center.x - 220, y: center.y - 220),
                           end: CGPoint(x: center.x + 220, y: center.y + 220),
                           options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
}
let dot = layer { ctx in
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: dotRect)
}

let image = layer { ctx in
    ctx.setFillColor(rgb(0x0E0D13))
    ctx.fill(full)
    // Halo diffus derrière le logo.
    ctx.drawRadialGradient(gradient([rgb(0x7B4CF0, 0.22), rgb(0x7B4CF0, 0)], [0, 1]),
                           startCenter: center, startRadius: 0, endCenter: center, endRadius: 760, options: [])
    ctx.setAlpha(0.7)
    ctx.draw(blurred(ring, 40), in: full)
    ctx.setAlpha(0.6)
    ctx.draw(blurred(dot, 30), in: full)
    ctx.setAlpha(1)
    ctx.draw(ring, in: full)
    // Reflet sur le bord extérieur, en haut à gauche.
    let rim = CGMutablePath()
    rim.addArc(center: center, radius: 62 * scale + 13 * scale - 6, startAngle: 108 * .pi / 180, endAngle: 200 * .pi / 180, clockwise: false)
    ctx.addPath(rim)
    ctx.setStrokeColor(rgb(0xFFFFFF, 0.6))
    ctx.setLineWidth(6)
    ctx.setLineCap(.round)
    ctx.strokePath()
    ctx.draw(dot, in: full)

    // Logotype et accroche.
    let graphics = NSGraphicsContext(cgContext: ctx, flipped: false)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = graphics
    let word = NSAttributedString(string: "hello", attributes: [
        .font: NSFont.systemFont(ofSize: 300, weight: .semibold),
        .foregroundColor: NSColor(srgbRed: 0.96, green: 0.95, blue: 0.98, alpha: 1),
        .kern: -14,
    ])
    word.draw(at: NSPoint(x: 1060, y: 430))
    let tagline = NSAttributedString(string: "Le lanceur macOS qui change de peau.", attributes: [
        .font: NSFont.systemFont(ofSize: 64, weight: .regular),
        .foregroundColor: NSColor(srgbRed: 0.75, green: 0.73, blue: 0.82, alpha: 1),
        .kern: -0.5,
    ])
    tagline.draw(at: NSPoint(x: 1072, y: 330))
    NSGraphicsContext.restoreGraphicsState()
}

let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "docs/banner.png"))
print("✓ docs/banner.png")
