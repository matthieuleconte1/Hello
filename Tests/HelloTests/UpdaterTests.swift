import XCTest
@testable import Hello

final class UpdaterTests: XCTestCase {
    func testVersionOrder() {
        XCTAssertEqual(Updater.compare("2.0.0", "2.0.0-alpha.2"), 1)
        XCTAssertEqual(Updater.compare("2.0.0-alpha.2", "2.0.0-alpha.10"), -1)
        XCTAssertEqual(Updater.compare("2.0.0-alpha.2", "2.0.0-beta.1"), -1)
        XCTAssertEqual(Updater.compare("1.9", "2.0.0-alpha.1"), -1)
        XCTAssertEqual(Updater.compare("2.0", "2.0.0"), 0)
    }

    /// Une étiquette de release mal formée ne doit pas faire planter la vérification.
    func testMalformedVersionsDoNotCrash() {
        XCTAssertEqual(Updater.compare("", "0"), 0)
        XCTAssertEqual(Updater.compare("-beta", "0"), -1)
        XCTAssertEqual(Updater.compare("2.0.0", ""), 1)
    }
}
