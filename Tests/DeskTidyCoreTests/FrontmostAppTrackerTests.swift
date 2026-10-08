import XCTest
@testable import DeskTidyCore

final class FrontmostAppTrackerTests: XCTestCase {
    private let ownPID: Int32 = 999
    private let me = RunningApp(bundleID: "DeskTidy", name: "桌面清理", processID: 999)
    private let safari = RunningApp(bundleID: "com.apple.Safari", name: "Safari", processID: 101)
    private let notes = RunningApp(bundleID: "com.apple.Notes", name: "备忘录", processID: 102)

    func testStartsWithInitialApp() {
        let tracker = FrontmostAppTracker(ownProcessID: ownPID, initial: safari)
        XCTAssertEqual(tracker.current, safari)
    }

    func testIgnoresOwnAppAsInitial() {
        let tracker = FrontmostAppTracker(ownProcessID: ownPID, initial: me)
        XCTAssertNil(tracker.current)
    }

    func testRemembersLastActivatedApp() {
        var tracker = FrontmostAppTracker(ownProcessID: ownPID)
        tracker.appDidActivate(safari)
        tracker.appDidActivate(notes)
        XCTAssertEqual(tracker.current, notes)
    }

    func testOpeningPanelDoesNotReplaceCurrentApp() {
        var tracker = FrontmostAppTracker(ownProcessID: ownPID)
        tracker.appDidActivate(safari)
        tracker.appDidActivate(me)
        XCTAssertEqual(tracker.current, safari)
    }

    func testForgetsCurrentAppWhenItQuits() {
        var tracker = FrontmostAppTracker(ownProcessID: ownPID, initial: safari)
        tracker.appDidTerminate(processID: safari.processID)
        XCTAssertNil(tracker.current)
    }

    func testOtherAppQuittingKeepsCurrentApp() {
        var tracker = FrontmostAppTracker(ownProcessID: ownPID, initial: safari)
        tracker.appDidTerminate(processID: notes.processID)
        XCTAssertEqual(tracker.current, safari)
    }
}
