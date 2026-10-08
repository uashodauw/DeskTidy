import XCTest
@testable import DeskTidyCore

final class CleanupFeedbackTests: XCTestCase {
    func testShowsHowManyAppsWereHidden() {
        XCTAssertEqual(CleanupFeedback(hiddenCount: 2).message, "已收起 2 个应用")
    }

    func testSaysDesktopIsAlreadyCleanWhenNothingWasHidden() {
        XCTAssertEqual(CleanupFeedback(hiddenCount: 0).message, "桌面已经很清爽了")
    }

    func testUsesDifferentIconsForTheTwoCases() {
        XCTAssertNotEqual(CleanupFeedback(hiddenCount: 1).systemImage, CleanupFeedback(hiddenCount: 0).systemImage)
    }
}
