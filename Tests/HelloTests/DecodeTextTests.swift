import XCTest
@testable import Hello

final class DecodeTextTests: XCTestCase {
    func testFinishedFramePreservesAccentsSpacesAndEmoji() {
        for title in ["Réglages\u{00a0}Système", "Émoji 🫧", "", "Safari"] {
            XCTAssertEqual(DecodeText.frame(title, progress: 1), title)
            XCTAssertEqual(DecodeText.frame(title, progress: 2), title)
        }
    }

    func testFiniteScheduleDoesNotReschedulePastDeadline() {
        let end = Date(timeIntervalSince1970: 100)
        let schedule = DecodeSchedule(end: end)
        let frames = schedule.entries(from: end.addingTimeInterval(-0.2), mode: .normal)
        XCTAssertEqual(frames.last, end)
        XCTAssertTrue(schedule.entries(from: end, mode: .normal).isEmpty)
        XCTAssertTrue(schedule.entries(from: end.addingTimeInterval(1), mode: .normal).isEmpty)
    }

    func testClockCascadesOnOpeningThenOnlyDecodesNewcomersAndSelection() {
        let clock = DecodeClock()
        let reveal = Date()
        let opening = clock.arrivals(["a", "b"], selected: "a", reveal: reveal)
        XCTAssertFalse(opening[0].quick)
        XCTAssertLessThan(opening[0].start, opening[1].start)

        // En tapant : « a » garde son décodage d'ouverture, « c » arrive en version brève.
        let typing = clock.arrivals(["a", "c"], selected: "a", reveal: reveal)
        XCTAssertEqual(typing[0], opening[0])
        XCTAssertTrue(typing[1].quick)
        XCTAssertEqual(clock.cue(typing[0], id: "a"), typing[0])

        // Sélectionner « c » le décode à nouveau, brièvement ; « a » reste tel quel.
        Thread.sleep(forTimeInterval: 0.05)
        let moved = clock.arrivals(["a", "c"], selected: "c", reveal: reveal)
        XCTAssertGreaterThan(clock.cue(moved[1], id: "c").start, typing[1].start)
        XCTAssertEqual(clock.cue(moved[0], id: "a"), opening[0])
    }

    func testClockTreatsStaleRevealAsNewScreen() {
        let clock = DecodeClock()
        let cues = clock.arrivals(["a"], selected: "a", reveal: Date().addingTimeInterval(-5))
        XCTAssertTrue(cues[0].quick)
    }
}
