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
}
