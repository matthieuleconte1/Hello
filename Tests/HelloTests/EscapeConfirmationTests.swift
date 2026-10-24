import AppKit
import Carbon
import XCTest
@testable import Hello

final class EscapeConfirmationTests: XCTestCase {
    func testTwoPressesConfirmOnce() {
        var confirmation = EscapeConfirmation()
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(confirmation.press(.leave, at: now))
        XCTAssertTrue(confirmation.press(.leave, at: now.addingTimeInterval(1)))
        XCTAssertFalse(confirmation.press(.leave, at: now.addingTimeInterval(1.1)))
    }

    func testExpiredPressStartsNewConfirmation() {
        var confirmation = EscapeConfirmation()
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(confirmation.press(.cancel, at: now))
        XCTAssertFalse(confirmation.press(.cancel, at: now.addingTimeInterval(2.5)))
        XCTAssertTrue(confirmation.press(.cancel, at: now.addingTimeInterval(3)))
    }

    func testCompletionBetweenPressesCannotDismissAnswer() {
        var confirmation = EscapeConfirmation()
        let now = Date(timeIntervalSince1970: 100)
        XCTAssertFalse(confirmation.press(.cancel, at: now))
        XCTAssertFalse(confirmation.press(.leave, at: now.addingTimeInterval(0.5)))
        XCTAssertTrue(confirmation.press(.leave, at: now.addingTimeInterval(1)))
    }

    func testResetDisarmsConfirmation() {
        var confirmation = EscapeConfirmation()
        XCTAssertFalse(confirmation.press(.leave))
        confirmation.reset()
        XCTAssertFalse(confirmation.press(.leave))
    }

    @MainActor func testFinishedAnswerNeedsTwoDistinctEscapes() {
        let model = LauncherModel()
        model.enter(.agent)
        model.attachAgent(AgentRun(restoring: ChatConversation()))
        func escape(repeating: Bool = false) {
            let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                windowNumber: 0, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}",
                isARepeat: repeating, keyCode: UInt16(kVK_Escape))!
            XCTAssertTrue(model.handleKey(event))
        }
        escape()
        XCTAssertEqual(model.mode, .agent)
        escape(repeating: true)
        XCTAssertEqual(model.mode, .agent)
        escape()
        XCTAssertEqual(model.mode, .root)
        XCTAssertNil(model.agent)
    }
}
