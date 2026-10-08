import XCTest
@testable import DeskTidyCore

final class CleanupPlannerTests: XCTestCase {
    private let safari = RunningApp(bundleID: "com.apple.Safari", name: "Safari", processID: 101)
    private let notes = RunningApp(bundleID: "com.apple.Notes", name: "备忘录", processID: 102)
    private let calculator = RunningApp(bundleID: "com.apple.calculator", name: "计算器", processID: 103)

    func testKeepsCurrentAppAndHidesOthers() {
        let result = CleanupPlanner.appsToHide(running: [safari, notes, calculator], current: safari)
        XCTAssertEqual(result, [notes, calculator])
    }

    func testMatchesCurrentAppByBundleIDNotName() {
        let safariWithEnglishName = RunningApp(bundleID: "com.apple.Safari", name: "Safari 浏览器", processID: 101)
        let result = CleanupPlanner.appsToHide(running: [safari, notes], current: safariWithEnglishName)
        XCTAssertEqual(result, [notes])
    }

    func testHidesEverythingWhenCurrentAppIsUnknown() {
        let result = CleanupPlanner.appsToHide(running: [safari, notes], current: nil)
        XCTAssertEqual(result, [safari, notes])
    }

    func testNothingToHideWhenOnlyCurrentAppIsRunning() {
        XCTAssertEqual(CleanupPlanner.appsToHide(running: [safari], current: safari), [])
    }
}
