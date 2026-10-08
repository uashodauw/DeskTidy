import XCTest
@testable import DeskTidyCore

final class IdleAppFinderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let calculator = RunningApp(bundleID: "com.apple.calculator", name: "计算器", processID: 1)
    private let safari = RunningApp(bundleID: "com.apple.Safari", name: "Safari", processID: 2)
    private let notes = RunningApp(bundleID: "com.apple.Notes", name: "备忘录", processID: 3)

    private func find(
        running: [RunningApp],
        current: RunningApp? = nil,
        kept: [String] = [],
        minutesAgo: [String: Double],
        threshold: IdleThreshold = .oneMinute
    ) -> [RunningApp] {
        IdleAppFinder.idleApps(
            running: running,
            current: current,
            keptBundleIDs: kept,
            lastUsed: { app in minutesAgo[app.bundleID].map { self.now.addingTimeInterval(-$0 * 60) } },
            now: now,
            threshold: threshold.seconds
        )
    }

    func testAppUnusedLongerThanThresholdIsIdle() {
        let idle = find(running: [calculator], minutesAgo: [calculator.bundleID: 2])
        XCTAssertEqual(idle, [calculator])
    }

    func testRecentlyUsedAppIsNotIdle() {
        let idle = find(running: [calculator], minutesAgo: [calculator.bundleID: 0.5])
        XCTAssertEqual(idle, [])
    }

    func testCurrentAppIsNeverIdle() {
        let idle = find(running: [safari], current: safari, minutesAgo: [safari.bundleID: 90])
        XCTAssertEqual(idle, [])
    }

    func testAppInSceneIsNeverIdle() {
        let idle = find(running: [safari], kept: [safari.bundleID], minutesAgo: [safari.bundleID: 90])
        XCTAssertEqual(idle, [])
    }

    func testAppWithoutUsageRecordIsNotIdle() {
        let idle = find(running: [notes], minutesAgo: [:])
        XCTAssertEqual(idle, [])
    }

    func testLongerThresholdHidesTheList() {
        let idle = find(running: [calculator], minutesAgo: [calculator.bundleID: 2], threshold: .oneHour)
        XCTAssertEqual(idle, [])
    }

    func testOnlyIdleAppsAreReturned() {
        let idle = find(
            running: [calculator, notes, safari],
            current: safari,
            minutesAgo: [calculator.bundleID: 5, notes.bundleID: 0.2, safari.bundleID: 5]
        )
        XCTAssertEqual(idle, [calculator])
    }
}
