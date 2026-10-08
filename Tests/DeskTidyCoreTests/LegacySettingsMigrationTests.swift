import XCTest
@testable import DeskTidyCore

final class LegacySettingsMigrationTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        suiteName = "DeskTidyTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testCopiesOldSettings() {
        let moved = LegacySettingsMigration.migrate(
            legacy: ["soundEnabled": false, "selectedSceneID": "meeting"],
            into: defaults
        )
        XCTAssertTrue(moved)
        XCTAssertEqual(defaults.object(forKey: "soundEnabled") as? Bool, false)
        XCTAssertEqual(defaults.string(forKey: "selectedSceneID"), "meeting")
    }

    func testMovedSettingsAreReadByTheApp() {
        LegacySettingsMigration.migrate(legacy: ["soundEnabled": false], into: defaults)
        XCTAssertFalse(AppSettings(defaults: defaults).soundEnabled)
    }

    func testRunsOnlyOnce() {
        LegacySettingsMigration.migrate(legacy: ["selectedSceneID": "meeting"], into: defaults)
        defaults.set("design", forKey: "selectedSceneID")
        let movedAgain = LegacySettingsMigration.migrate(legacy: ["selectedSceneID": "meeting"], into: defaults)
        XCTAssertFalse(movedAgain)
        XCTAssertEqual(defaults.string(forKey: "selectedSceneID"), "design")
    }

    func testDoesNotOverwriteNewSettings() {
        defaults.set("design", forKey: "selectedSceneID")
        LegacySettingsMigration.migrate(legacy: ["selectedSceneID": "meeting"], into: defaults)
        XCTAssertEqual(defaults.string(forKey: "selectedSceneID"), "design")
    }

    func testNothingToMove() {
        XCTAssertFalse(LegacySettingsMigration.migrate(legacy: nil, into: defaults))
        XCTAssertNil(defaults.string(forKey: "selectedSceneID"))
    }
}
