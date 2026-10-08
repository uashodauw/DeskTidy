import XCTest
@testable import DeskTidyCore

final class CleanupRecordTests: XCTestCase {
    private let notes = RunningApp(bundleID: "com.apple.Notes", name: "备忘录", processID: 102)
    private let calculator = RunningApp(bundleID: "com.apple.calculator", name: "计算器", processID: 103)

    private func hidden(_ app: RunningApp) -> RunningApp {
        RunningApp(bundleID: app.bundleID, name: app.name, processID: app.processID, isHidden: true)
    }

    func testStartsEmpty() {
        XCTAssertTrue(CleanupRecord().isEmpty)
    }

    func testAddingTheSameAppTwiceKeepsOneEntry() {
        var record = CleanupRecord()
        record.add([notes])
        record.add([notes, calculator])
        XCTAssertEqual(record.hiddenBundleIDs, [notes.bundleID, calculator.bundleID])
    }

    func testDoesNotRestoreAppTheUserHidThemselves() {
        var record = CleanupRecord()
        record.add([notes])
        let running = [hidden(notes), hidden(calculator)]
        XCTAssertEqual(record.appsToRestore(running: running), [hidden(notes)])
    }

    func testSkipsRecordedAppThatIsAlreadyVisibleAgain() {
        var record = CleanupRecord()
        record.add([notes])
        XCTAssertEqual(record.appsToRestore(running: [notes]), [])
    }

    func testRestoresAppAfterItRestartedWithNewProcessID() {
        var record = CleanupRecord()
        record.add([notes])
        let restartedNotes = RunningApp(bundleID: notes.bundleID, name: notes.name, processID: 555, isHidden: true)
        XCTAssertEqual(record.appsToRestore(running: [restartedNotes]), [restartedNotes])
    }
}
