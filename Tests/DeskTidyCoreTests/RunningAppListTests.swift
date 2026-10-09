import XCTest
@testable import DeskTidyCore

final class RunningAppListTests: XCTestCase {
    private let safari = RunningApp(bundleID: "com.apple.Safari", name: "Safari", processID: 101)
    private let calculator = RunningApp(bundleID: "com.apple.calculator", name: "Calculator", processID: 102)
    private let notes = RunningApp(bundleID: "com.apple.Notes", name: "Notes", processID: 103)

    func testExcludesOwnProcess() {
        let result = RunningAppList.make(from: [safari, calculator], excludingProcessID: 101)
        XCTAssertEqual(result, [calculator])
    }

    func testRemovesDuplicateBundleIDs() {
        let secondSafari = RunningApp(bundleID: "com.apple.Safari", name: "Safari", processID: 201)
        let result = RunningAppList.make(from: [safari, secondSafari], excludingProcessID: 0)
        XCTAssertEqual(result, [safari])
    }

    func testSortsByName() {
        let result = RunningAppList.make(from: [safari, notes, calculator], excludingProcessID: 0)
        XCTAssertEqual(result.map(\.name), ["Calculator", "Notes", "Safari"])
    }

    func testEmptyInputGivesEmptyList() {
        XCTAssertEqual(RunningAppList.make(from: [], excludingProcessID: 0), [])
    }

    private let now = Date(timeIntervalSince1970: 1_000_000)

    func testRecentUseSortsNewestFirst() {
        let times = [safari.bundleID: now.addingTimeInterval(-3600),
                     notes.bundleID: now.addingTimeInterval(-60),
                     calculator.bundleID: now.addingTimeInterval(-86400)]
        let result = RunningAppList.sortedByRecentUse([safari, notes, calculator], currentBundleID: nil) { times[$0.bundleID] }
        XCTAssertEqual(result.map(\.name), ["Notes", "Safari", "Calculator"])
    }

    func testCurrentAppComesFirstEvenIfOlderRecord() {
        let times = [safari.bundleID: now.addingTimeInterval(-86400),
                     notes.bundleID: now]
        let result = RunningAppList.sortedByRecentUse([notes, safari], currentBundleID: safari.bundleID) { times[$0.bundleID] }
        XCTAssertEqual(result.map(\.name), ["Safari", "Notes"])
    }

    func testAppsWithoutRecordGoLastByName() {
        let times = [notes.bundleID: now]
        let result = RunningAppList.sortedByRecentUse([safari, calculator, notes], currentBundleID: nil) { times[$0.bundleID] }
        XCTAssertEqual(result.map(\.name), ["Notes", "Calculator", "Safari"])
    }

    func testSameTimeFallsBackToName() {
        let result = RunningAppList.sortedByRecentUse([safari, calculator], currentBundleID: nil) { _ in self.now }
        XCTAssertEqual(result.map(\.name), ["Calculator", "Safari"])
    }
}
