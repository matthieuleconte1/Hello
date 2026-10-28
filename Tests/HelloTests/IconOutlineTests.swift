import CoreGraphics
import XCTest
@testable import Hello

final class IconOutlineTests: XCTestCase {
    /// Un carré opaque gris, un carré blanc au milieu : le filet suit le bord, le trait intérieur le carré blanc.
    private func icon() -> CGImage {
        let context = CGContext(data: nil, width: 128, height: 128, bitsPerComponent: 8, bytesPerRow: 0,
                                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.setFillColor(CGColor(gray: 0.3, alpha: 1))
        context.fill(CGRect(x: 16, y: 16, width: 96, height: 96))
        context.setFillColor(CGColor(gray: 1, alpha: 1))
        context.fill(CGRect(x: 48, y: 48, width: 32, height: 32))
        return context.makeImage()!
    }

    private func alpha(_ image: CGImage, x: Int, y: Int) -> UInt8 {
        let data = CFDataGetBytePtr(image.dataProvider!.data)!
        return data[y * image.bytesPerRow + x * 4 + 3]
    }

    func testRingOnly() throws {
        let ring = try XCTUnwrap(IconOutline.make(icon(), side: 128, radius: 4.5))
        XCTAssertGreaterThan(alpha(ring, x: 18, y: 64), 200)   // bord de l'icône
        XCTAssertEqual(alpha(ring, x: 48, y: 64), 0)           // pas de trait intérieur
        XCTAssertEqual(alpha(ring, x: 4, y: 64), 0)            // dehors
    }

    func testInnerLines() throws {
        let drawing = try XCTUnwrap(IconOutline.make(icon(), side: 128, radius: 4.5, detail: 0.6))
        XCTAssertGreaterThan(alpha(drawing, x: 18, y: 64), 200)
        // Le bord du carré blanc est détouré, du côté sombre ; son centre et le gris uni restent vides.
        XCTAssertGreaterThan((42...50).map { alpha(drawing, x: $0, y: 64) }.max()!, 128)
        XCTAssertEqual(alpha(drawing, x: 64, y: 64), 0)
        XCTAssertEqual(alpha(drawing, x: 32, y: 64), 0)
    }
}
