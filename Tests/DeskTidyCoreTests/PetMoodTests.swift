import XCTest
@testable import DeskTidyCore

final class PetMoodTests: XCTestCase {
    func testFewAppsMakeThePetHappy() {
        XCTAssertEqual(PetMood.from(visibleAppCount: 0), .happy)
        XCTAssertEqual(PetMood.from(visibleAppCount: 4), .happy)
    }

    func testSomeAppsKeepThePetCalm() {
        XCTAssertEqual(PetMood.from(visibleAppCount: 5), .calm)
        XCTAssertEqual(PetMood.from(visibleAppCount: 9), .calm)
    }

    func testManyAppsMakeThePetDizzy() {
        XCTAssertEqual(PetMood.from(visibleAppCount: 10), .dizzy)
        XCTAssertEqual(PetMood.from(visibleAppCount: 30), .dizzy)
    }

    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testFirstDizzyHintIsShown() {
        XCTAssertTrue(PetHintPolicy.shouldShowDizzyHint(lastShown: nil, now: now))
    }

    func testDizzyHintIsNotRepeatedWithinHalfAnHour() {
        XCTAssertFalse(PetHintPolicy.shouldShowDizzyHint(lastShown: now.addingTimeInterval(-29 * 60), now: now))
    }

    func testDizzyHintCanReturnAfterHalfAnHour() {
        XCTAssertTrue(PetHintPolicy.shouldShowDizzyHint(lastShown: now.addingTimeInterval(-30 * 60), now: now))
    }
}
