import AppKit
import Combine
import SwiftUI
import XCTest
@testable import Hello

final class AppPagerTests: XCTestCase {
    func testDragDoesNotInvalidateLauncher() {
        let model = LauncherModel()
        var launcherChanges = 0
        let observation = model.objectWillChange.sink { launcherChanges += 1 }
        for offset in 0..<120 { model.pager.drag(CGFloat(-offset), page: 1, width: 900) }
        XCTAssertEqual(launcherChanges, 0)
        XCTAssertEqual(model.pager.position, -1 - 119.0 / 900, accuracy: 0.0001)
        withExtendedLifetime(observation) {}
    }

    func testReleaseUsesOneContinuousPosition() {
        let pager = PagerState()
        var positions: [CGFloat] = []
        let observation = pager.$position.dropFirst().sink { positions.append($0) }
        pager.drag(-225, page: 0, width: 900)
        pager.settle(page: 1)
        XCTAssertEqual(positions, [-0.25, -1])
        pager.reset()
        XCTAssertEqual(pager.position, 0)
        withExtendedLifetime(observation) {}
    }

    @MainActor func testLeavingAndReopeningGridClearsDrag() async {
        let model = LauncherModel()
        model.enter(.apps)
        model.selection = 5 * model.appsPerPage
        model.pager.drag(-225, page: model.appPage, width: 900)
        model.back()
        XCTAssertEqual(model.mode, .root)
        XCTAssertEqual(model.pager.position, 0)
        model.enter(.apps)
        XCTAssertEqual(model.appPage, 0)
        XCTAssertEqual(model.appPageRange, 0...1)
        XCTAssertEqual(model.pager.position, 0)
        model.reset(to: .root)
        XCTAssertEqual(model.appPage, 0)
        XCTAssertEqual(model.pager.position, 0)
    }

    func testZeroWidthDoesNotCorruptPosition() {
        let pager = PagerState()
        pager.settle(page: 2)
        pager.drag(-30, page: 2, width: 0)
        XCTAssertEqual(pager.position, -2)
    }
}
