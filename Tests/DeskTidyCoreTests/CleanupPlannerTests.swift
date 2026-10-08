import XCTest
@testable import DeskTidyCore

final class CleanupPlannerTests: XCTestCase {
    private let safari = RunningApp(bundleID: "com.apple.Safari", name: "Safari", processID: 101)
    private let notes = RunningApp(bundleID: "com.apple.Notes", name: "备忘录", processID: 102)
    private let calculator = RunningApp(bundleID: "com.apple.calculator", name: "计算器", processID: 103)

    private let aiWork = DefaultScenes.all[0].keptBundleIDs
    private let meeting = DefaultScenes.all[2].keptBundleIDs

    func testKeepsCurrentAppAndHidesOthers() {
        let result = CleanupPlanner.appsToHide(running: [safari, notes, calculator], current: safari, keptBundleIDs: [])
        XCTAssertEqual(result, [notes, calculator])
    }

    func testMatchesCurrentAppByBundleIDNotName() {
        let safariWithEnglishName = RunningApp(bundleID: "com.apple.Safari", name: "Safari 浏览器", processID: 101)
        let result = CleanupPlanner.appsToHide(running: [safari, notes], current: safariWithEnglishName, keptBundleIDs: [])
        XCTAssertEqual(result, [notes])
    }

    func testHidesEverythingWhenCurrentAppIsUnknown() {
        let result = CleanupPlanner.appsToHide(running: [safari, notes], current: nil, keptBundleIDs: [])
        XCTAssertEqual(result, [safari, notes])
    }

    func testSkipsAppsTheUserAlreadyHid() {
        let hiddenCalculator = RunningApp(bundleID: "com.apple.calculator", name: "计算器", processID: 103, isHidden: true)
        let result = CleanupPlanner.appsToHide(running: [safari, notes, hiddenCalculator], current: safari, keptBundleIDs: [])
        XCTAssertEqual(result, [notes])
    }

    func testNothingToHideWhenOnlyCurrentAppIsRunning() {
        XCTAssertEqual(CleanupPlanner.appsToHide(running: [safari], current: safari, keptBundleIDs: []), [])
    }

    func testAIWorkSceneKeepsSafariAndCurrentApp() {
        let result = CleanupPlanner.appsToHide(running: [safari, notes, calculator], current: notes, keptBundleIDs: aiWork)
        XCTAssertEqual(result, [calculator])
    }

    func testMeetingSceneHidesSafari() {
        let result = CleanupPlanner.appsToHide(running: [safari, notes, calculator], current: notes, keptBundleIDs: meeting)
        XCTAssertEqual(result, [safari, calculator])
    }
}
