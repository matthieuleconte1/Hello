import AppKit
import SwiftUI

/// Grain de matière commun aux peaux (papier, émail, laque, dalle e-ink, aluminium).
///
/// Un bruit d'un seul pixel Retina à 2–4 % d'opacité disparaît à l'œil : ce grain-ci est tiré par cellules
/// d'un point (fin) mêlées à des cellules de deux points (doux), avec une amplitude linéaire et quelques
/// mouchetures plus franches, si bien qu'il se lit comme une texture sans jamais gêner le texte.
enum Grain {
    struct Spec: Hashable {
        /// Opacité maximale d'un grain (0,06 : discret, 0,12 : franc).
        var amount: Double
        /// Teinte des creux (assombrissements) et des reliefs (éclaircissements), en sRGB 0–1.
        var shadow: RGB = .init(r: 0, g: 0, b: 0)
        var light: RGB = .init(r: 1, g: 1, b: 1)
        /// Part des reliefs clairs face aux creux (0 : que des creux, 1 : équilibré).
        var lightShare: Double = 0.8
        /// Densité des mouchetures (inclusions plus sombres, 1 pt).
        var specks: Double = 0.006
        var seed: UInt64 = 0x5DEE_CE66_D1CE_4E5B
    }

    struct RGB: Hashable {
        var r: Double, g: Double, b: Double
    }

    private static var cache: [Spec: NSImage] = [:]

    static func tile(_ spec: Spec) -> NSImage {
        if let image = cache[spec] { return image }
        let image = make(spec)
        cache[spec] = image
        return image
    }

    private static func make(_ spec: Spec) -> NSImage {
        let side = 128, scale = 2
        let px = side * scale
        guard let ctx = CGContext(data: nil, width: px, height: px, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let data = ctx.data?.assumingMemoryBound(to: UInt8.self) else {
            return NSImage(size: NSSize(width: side, height: side))
        }
        let stride = ctx.bytesPerRow
        func hash(_ x: Int, _ y: Int, _ salt: UInt64) -> Double {
            var h = spec.seed &+ UInt64(truncatingIfNeeded: x) &* 0x9E37_79B9_7F4A_7C15
            h ^= UInt64(truncatingIfNeeded: y) &* 0xC2B2_AE3D_27D4_EB4F &+ salt
            h ^= h >> 31; h = h &* 0xBF58_476D_1CE4_E5B9; h ^= h >> 29
            return Double(h & 0xFFFF) / 65_535.0
        }
        // Cellules d'un point (2 px) et de deux points (4 px), répétées sans couture (tuile de 128 pt).
        for y in 0..<px {
            for x in 0..<px {
                let fine = hash(x / 2, y / 2, 11) * 2 - 1
                let soft = hash(x / 4, y / 4, 29) * 2 - 1
                var v = fine * 0.68 + soft * 0.32
                var alpha = abs(v) * spec.amount
                if hash(x / 2, y / 2, 97) < spec.specks {
                    v = -1
                    alpha = min(1, spec.amount * 2.4)
                } else if v > 0 {
                    alpha *= spec.lightShare
                }
                let c = v > 0 ? spec.light : spec.shadow
                let a = min(max(alpha, 0), 1)
                let i = y * stride + x * 4
                data[i] = UInt8(c.r * a * 255)
                data[i + 1] = UInt8(c.g * a * 255)
                data[i + 2] = UInt8(c.b * a * 255)
                data[i + 3] = UInt8(a * 255)
            }
        }
        guard let cg = ctx.makeImage() else { return NSImage(size: NSSize(width: side, height: side)) }
        return NSImage(cgImage: cg, size: NSSize(width: side, height: side))
    }
}

/// Calque de grain qui remplit son cadre (à poser dans un `ZStack`, sous le contenu).
struct GrainLayer: View {
    let spec: Grain.Spec

    var body: some View {
        Rectangle()
            .fill(ImagePaint(image: Image(nsImage: Grain.tile(spec))))
            .allowsHitTesting(false)
    }
}
