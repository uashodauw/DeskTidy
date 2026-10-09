import XCTest
@testable import DeskTidyCore

final class QuitRulesTests: XCTestCase {
    func testOrdinaryAppsCanBeQuit() {
        let safari = RunningApp(bundleID: "com.apple.Safari", name: "Safari", processID: 1)
        XCTAssertTrue(QuitRules.canQuitFromPanel(safari))
    }

    func testFinderCannotBeQuit() {
        let finder = RunningApp(bundleID: "com.apple.finder", name: "访达", processID: 2)
        XCTAssertFalse(QuitRules.canQuitFromPanel(finder))
    }
}
