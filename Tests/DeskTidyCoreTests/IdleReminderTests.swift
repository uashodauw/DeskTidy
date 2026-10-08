import XCTest
@testable import DeskTidyCore

final class IdleReminderTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func remind(_ frequency: IdleReminderFrequency, minutesAgo: Double?, shownThisLaunch: Bool = false) -> Bool {
        IdleReminderPolicy.shouldRemind(
            frequency: frequency,
            lastShown: minutesAgo.map { now.addingTimeInterval(-$0 * 60) },
            shownThisLaunch: shownThisLaunch,
            now: now
        )
    }

    func testDefaultIsDaily() {
        XCTAssertEqual(IdleReminderFrequency.defaultValue, .daily)
    }

    func testFirstReminderIsAlwaysShown() {
        for frequency in IdleReminderFrequency.allCases {
            XCTAssertTrue(remind(frequency, minutesAgo: nil), "\(frequency)")
        }
    }

    func testDailyWaitsADay() {
        XCTAssertFalse(remind(.daily, minutesAgo: 60))
        XCTAssertFalse(remind(.daily, minutesAgo: 23 * 60))
        XCTAssertTrue(remind(.daily, minutesAgo: 24 * 60))
    }

    func testHourlyWaitsAnHour() {
        XCTAssertFalse(remind(.hourly, minutesAgo: 5))
        XCTAssertTrue(remind(.hourly, minutesAgo: 60))
    }

    func testOncePerLaunchIgnoresTime() {
        XCTAssertTrue(remind(.oncePerLaunch, minutesAgo: 1))
        XCTAssertFalse(remind(.oncePerLaunch, minutesAgo: 3 * 24 * 60, shownThisLaunch: true))
    }

    func testEveryCleanupAlwaysReminds() {
        XCTAssertTrue(remind(.everyCleanup, minutesAgo: 0, shownThisLaunch: true))
    }

    func testClockMovedBackwardAllowsReminder() {
        XCTAssertTrue(remind(.daily, minutesAgo: -60))
    }
}

final class IdleReminderSettingsTests: XCTestCase {
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

    func testFrequencyIsDailyByDefaultAndRemembered() {
        XCTAssertEqual(AppSettings(defaults: defaults).idleReminderFrequency, .daily)
        AppSettings(defaults: defaults).idleReminderFrequency = .hourly
        XCTAssertEqual(AppSettings(defaults: defaults).idleReminderFrequency, .hourly)
    }

    func testLastShownSurvivesRestart() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        AppSettings(defaults: defaults).idleReminderLastShown = date
        XCTAssertEqual(AppSettings(defaults: defaults).idleReminderLastShown, date)
    }

    func testUnknownFrequencyFallsBackToDefault() {
        defaults.set("乱码", forKey: AppSettings.idleReminderFrequencyKey)
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.idleReminderFrequency, .daily)
        XCTAssertTrue(settings.recoveredFromCorruptData)
    }

    func testBrokenLastShownIsDroppedQuietly() {
        defaults.set("乱码", forKey: AppSettings.idleReminderLastShownKey)
        let settings = AppSettings(defaults: defaults)
        XCTAssertNil(settings.idleReminderLastShown)
        XCTAssertFalse(settings.recoveredFromCorruptData)
    }
}
