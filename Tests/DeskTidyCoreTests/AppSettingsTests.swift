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

    func testWelcomeIsNotShownYetOnFreshInstall() {
        XCTAssertFalse(AppSettings(defaults: defaults).welcomeShown)
    }

    func testWelcomeShownIsRemembered() {
        AppSettings(defaults: defaults).welcomeShown = true
        XCTAssertTrue(AppSettings(defaults: defaults).welcomeShown)
    }

    func testBrokenWelcomeFlagIsDroppedSilently() {
        defaults.set("yes", forKey: AppSettings.welcomeShownKey)
        let settings = AppSettings(defaults: defaults)
        XCTAssertFalse(settings.welcomeShown)
        XCTAssertFalse(settings.recoveredFromCorruptData)
    }

    func testCleanSoundIsMailSentByDefaultAndRemembered() {
        XCTAssertEqual(AppSettings(defaults: defaults).cleanSound, .mailSent)
        AppSettings(defaults: defaults).cleanSound = .glass
        XCTAssertEqual(AppSettings(defaults: defaults).cleanSound, .glass)
    }

    func testUnknownCleanSoundFallsBackToDefault() {
        defaults.set("乱码", forKey: AppSettings.cleanSoundKey)
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.cleanSound, .mailSent)
        XCTAssertTrue(settings.recoveredFromCorruptData)
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
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.idleThreshold, .oneHour)
        XCTAssertTrue(settings.recoveredFromCorruptData)
    }

    func testNormalSettingsAreNotReportedAsRecovered() {
        let settings = AppSettings(defaults: defaults)
        settings.soundEnabled = false
        settings.idleThreshold = .twoHours
        XCTAssertFalse(AppSettings(defaults: defaults).recoveredFromCorruptData)
    }

    func testTextInsteadOfSoundSettingFallsBackToDefault() {
        defaults.set("乱码乱码", forKey: AppSettings.soundEnabledKey)
        let settings = AppSettings(defaults: defaults)
        XCTAssertTrue(settings.soundEnabled)
        XCTAssertTrue(settings.recoveredFromCorruptData)
        XCTAssertFalse(AppSettings(defaults: defaults).recoveredFromCorruptData)
    }
}
