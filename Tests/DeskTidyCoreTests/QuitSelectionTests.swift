import XCTest
@testable import DeskTidyCore

final class QuitSelectionTests: XCTestCase {
    private let textEdit = RunningApp(bundleID: "com.apple.TextEdit", name: "文本编辑", processID: 1)
    private let calculator = RunningApp(bundleID: "com.apple.calculator", name: "计算器", processID: 2)

    func testNothingIsSelectedByDefault() {
        let selection = QuitSelection()
        XCTAssertTrue(selection.isEmpty)
        XCTAssertFalse(selection.isSelected(textEdit))
        XCTAssertEqual(selection.appsToQuit(from: [textEdit, calculator]), [])
    }

    func testOnlySelectedAppsAreQuit() {
        var selection = QuitSelection()
        selection.setSelected(textEdit, true)
        XCTAssertEqual(selection.appsToQuit(from: [textEdit, calculator]), [textEdit])
    }

    func testUnselectingRemovesTheApp() {
        var selection = QuitSelection()
        selection.setSelected(textEdit, true)
        selection.setSelected(textEdit, false)
        XCTAssertTrue(selection.isEmpty)
        XCTAssertEqual(selection.appsToQuit(from: [textEdit]), [])
    }

    func testSelectedAppNoLongerInListIsNotQuit() {
        var selection = QuitSelection()
        selection.setSelected(textEdit, true)
        XCTAssertEqual(selection.appsToQuit(from: [calculator]), [])
    }
}
