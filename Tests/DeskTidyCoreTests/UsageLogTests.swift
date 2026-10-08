import XCTest
@testable import DeskTidyCore

final class UsageLogTests: XCTestCase {
    private var suiteName = ""
    private var defaults: UserDefaults!
    private let calculator = "com.apple.calculator"

    override func setUp() {
        super.setUp()
        suiteName = "DeskTidyTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testUnknownAppHasNoLastUsedTime() {
        XCTAssertNil(UsageLog(defaults: defaults).lastUsed(calculator))
    }

    func testRemembersWhenAnAppWasUsed() {
        let log = UsageLog(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_000_000)
        log.recordUse(of: calculator, at: date)
        XCTAssertEqual(log.lastUsed(calculator), date)
    }

    func testLaterUseReplacesEarlierUse() {
        let log = UsageLog(defaults: defaults)
        log.recordUse(of: calculator, at: Date(timeIntervalSince1970: 1_000))
        log.recordUse(of: calculator, at: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(log.lastUsed(calculator), Date(timeIntervalSince1970: 2_000))
    }

    func testRecordIfUnknownSetsAStartingPoint() {
        let log = UsageLog(defaults: defaults)
        let date = Date(timeIntervalSince1970: 1_000)
        log.recordIfUnknown(calculator, at: date)
        XCTAssertEqual(log.lastUsed(calculator), date)
    }

    func testRecordIfUnknownKeepsExistingTime() {
        let log = UsageLog(defaults: defaults)
        log.recordUse(of: calculator, at: Date(timeIntervalSince1970: 1_000))
        log.recordIfUnknown(calculator, at: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(log.lastUsed(calculator), Date(timeIntervalSince1970: 1_000))
    }

    func testTimesSurviveARestart() {
        let date = Date(timeIntervalSince1970: 1_000_000)
        UsageLog(defaults: defaults).recordUse(of: calculator, at: date)
        XCTAssertEqual(UsageLog(defaults: defaults).lastUsed(calculator), date)
    }

    func testUnreadableSavedTimesStartEmpty() {
        defaults.set(Data("not json".utf8), forKey: UsageLog.key)
        XCTAssertNil(UsageLog(defaults: defaults).lastUsed(calculator))
    }

    func testDescribesRelativeTimes() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        func ago(_ seconds: TimeInterval) -> String {
            RelativeTime.describe(now.addingTimeInterval(-seconds), now: now)
        }
        XCTAssertEqual(ago(30), "刚刚")
        XCTAssertEqual(ago(90), "1 分钟前")
        XCTAssertEqual(ago(3 * 60), "3 分钟前")
        XCTAssertEqual(ago(2 * 3600), "2 小时前")
        XCTAssertEqual(ago(3 * 86400), "3 天前")
        XCTAssertEqual(ago(-60), "刚刚")
    }
}
