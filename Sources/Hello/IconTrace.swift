import CoreGraphics
import Foundation

/// Les traits intérieurs d'une icône, comme un dessin à l'encre : différence de deux flous gaussiens (XDoG, la
/// technique classique du rendu « au trait »). Chaque bord donne un seul trait, posé de son côté sombre, d'épaisseur
/// régulière et adouci par nature — là où un détecteur de contours rend des pixels épars, en escalier.
/// Avant : le contraste de l'icône est étiré (une icône grise sur gris garde ses formes) et son bord est prolongé
/// vers l'extérieur (le filet s'occupe du bord). Après : les taches isolées sont retirées.
enum IconTrace {
    /// Traits blancs sur noir, `side` × `side`, rangées de haut en bas (comme un `CGContext` bitmap).
    /// `detail` (0…1) : seuil du trait et taille minimale d'une tache gardée. `width` : épaisseur, en pixels.
    static func lines(_ image: CGImage, side: Int, detail: Double, width: Double) -> [UInt8]? {
        let detail = min(max(detail, 0), 1)
        let count = side * side
        var rgba = [UInt8](repeating: 0, count: count * 4)
        let drawn = rgba.withUnsafeMutableBytes { buffer -> Bool in
            guard let bitmap = CGContext(data: buffer.baseAddress, width: side, height: side, bitsPerComponent: 8,
                                         bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
            bitmap.interpolationQuality = .high
            bitmap.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }

        // Luminance (perçue) des pixels opaques.
        var luma = [Float](repeating: 0, count: count)
        var inside = [Bool](repeating: false, count: count)
        var values: [Float] = []
        for index in 0..<count where rgba[index * 4 + 3] >= 128 {
            let alpha = Float(rgba[index * 4 + 3])
            let r = Float(rgba[index * 4]) / alpha, g = Float(rgba[index * 4 + 1]) / alpha, b = Float(rgba[index * 4 + 2]) / alpha
            luma[index] = (0.2126 * r * r + 0.7152 * g * g + 0.0722 * b * b).squareRoot()
            inside[index] = true
            values.append(luma[index])
        }
        guard values.count > side else { return nil }

        // Contraste étiré entre les 2 % les plus sombres et les 2 % les plus clairs (pas au-delà de ×4 : une icône
        // presque unie ne doit pas faire ressortir son grain).
        values.sort()
        let low = values[values.count / 50]
        let high = values[values.count - 1 - values.count / 50]
        let range = max(high - low, 0.25)
        for index in 0..<count where inside[index] { luma[index] = min(max((luma[index] - low) / range, 0), 1) }

        extendOutward(&luma, inside: inside, side: side, passes: Int(width * 3) + 4)

        // XDoG : flou fin moins flou large. Positif du côté sombre d'un bord, d'autant plus que le bord contraste.
        let sigma = width * 0.55
        let fine = blur(luma, side: side, sigma: sigma)
        let wide = blur(luma, side: side, sigma: sigma * 1.6)
        let threshold = Float(0.05 - 0.035 * detail)
        let soft = threshold * 0.6
        var ink = [Float](repeating: 0, count: count)
        for index in 0..<count where inside[index] {
            let response = wide[index] - fine[index]
            let t = min(max((response - threshold) / soft + 0.5, 0), 1)
            ink[index] = t * t * (3 - 2 * t)
        }

        removeSpecks(&ink, side: side, minArea: Int(width * width * (14 - 10 * detail)))
        return ink.map { UInt8(min($0, 1) * 255) }
    }

    /// Prolonge les valeurs du bord vers l'extérieur (moyenne des voisins déjà connus, passe après passe) :
    /// le contour de l'icône ne fait pas de trait, seul ce qui est dedans en fait.
    private static func extendOutward(_ values: inout [Float], inside: [Bool], side: Int, passes: Int) {
        var known = inside
        for _ in 0..<passes {
            var next = known
            var changed = false
            for y in 0..<side {
                for x in 0..<side where !known[y * side + x] {
                    var sum: Float = 0
                    var n: Float = 0
                    for (nx, ny) in [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
                    where nx >= 0 && ny >= 0 && nx < side && ny < side && known[ny * side + nx] {
                        sum += values[ny * side + nx]
                        n += 1
                    }
                    if n > 0 {
                        values[y * side + x] = sum / n
                        next[y * side + x] = true
                        changed = true
                    }
                }
            }
            known = next
            if !changed { break }
        }
    }

    /// Flou gaussien séparable, bords prolongés.
    private static func blur(_ values: [Float], side: Int, sigma: Double) -> [Float] {
        let radius = max(Int((sigma * 3).rounded(.up)), 1)
        var kernel = (-radius...radius).map { Float(exp(-Double($0 * $0) / (2 * sigma * sigma))) }
        let total = kernel.reduce(0, +)
        kernel = kernel.map { $0 / total }
        var pass = [Float](repeating: 0, count: values.count)
        var result = [Float](repeating: 0, count: values.count)
        for y in 0..<side {
            let row = y * side
            for x in 0..<side {
                var sum: Float = 0
                for k in -radius...radius { sum += values[row + min(max(x + k, 0), side - 1)] * kernel[k + radius] }
                pass[row + x] = sum
            }
        }
        for y in 0..<side {
            for x in 0..<side {
                var sum: Float = 0
                for k in -radius...radius { sum += pass[min(max(y + k, 0), side - 1) * side + x] * kernel[k + radius] }
                result[y * side + x] = sum
            }
        }
        return result
    }

    /// Retire les taches d'encre (groupes de pixels encrés qui se touchent) plus petites que `minArea` pixels :
    /// grain, reflets et bouts de texture.
    private static func removeSpecks(_ ink: inout [Float], side: Int, minArea: Int) {
        var seen = [Bool](repeating: false, count: ink.count)
        var group: [Int] = []
        for start in ink.indices where ink[start] > 0.05 && !seen[start] {
            seen[start] = true
            var stack = [start]
            group.removeAll(keepingCapacity: true)
            var weight: Float = 0
            while let index = stack.popLast() {
                group.append(index)
                weight += ink[index]
                let x = index % side, y = index / side
                for ny in max(y - 1, 0)...min(y + 1, side - 1) {
                    for nx in max(x - 1, 0)...min(x + 1, side - 1) {
                        let next = ny * side + nx
                        if ink[next] > 0.05 && !seen[next] { seen[next] = true; stack.append(next) }
                    }
                }
            }
            if weight < Float(minArea) { for index in group { ink[index] = 0 } }
        }
    }
}
