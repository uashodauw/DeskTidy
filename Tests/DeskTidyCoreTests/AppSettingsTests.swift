import XCTest
@testable import DeskTidyCore

final class AppSettingsTests: XCTestCase {
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

    func testSoundIsOnByDefault() {
        XCTAssertTrue(AppSettings(defaults: defaults).soundEnabled)
    }

    func testTurningSoundOffIsRememberedByNewSettings() {
        AppSettings(defaults: defaults).soundEnabled = false
        XCTAssertFalse(AppSettings(defaults: defaults).soundEnabled)
    }

    func testTurningSoundBackOnIsRemembered() {
        let settings = AppSettings(defaults: defaults)
        settings.soundEnabled = false
        settings.soundEnabled = true
        XCTAssertTrue(AppSettings(defaults: defaults).soundEnabled)
    }

    func testIdleThresholdIsOneHourByDefault() {
        XCTAssertEqual(AppSettings(defaults: defaults).idleThreshold, .oneHour)
    }

    func testIdleThresholdIsRemembered() {
        AppSettings(defaults: defaults).idleThreshold = .oneMinute
        XCTAssertEqual(AppSettings(defaults: defaults).idleThreshold, .oneMinute)
    }

    func testUnknownSavedIdleThresholdFallsBackToDefault() {
        defaults.set(12345, forKey: AppSettings.idleThresholdKey)
        XCTAssertEqual(AppSettings(defaults: defaults).idleThreshold, .oneHour)
    }
}
