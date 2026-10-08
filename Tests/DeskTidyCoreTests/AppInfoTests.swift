import XCTest
@testable import DeskTidyCore

final class AppInfoTests: XCTestCase {
    func testDisplayNameIsSet() {
        XCTAssertEqual(AppInfo.displayName, "桌面清理")
    }

    func testVersionHasThreeParts() {
        XCTAssertEqual(AppInfo.version.split(separator: ".").count, 3)
    }
}
