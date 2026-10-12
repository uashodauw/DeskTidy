import XCTest
@testable import DeskTidyCore

final class FocusTimerTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)
    private let short = FocusDurations(focus: 100, shortBreak: 20, longBreak: 50, roundsBeforeLongBreak: 2)

    private func at(_ seconds: TimeInterval) -> Date {
        start.addingTimeInterval(seconds)
    }

    func testStartsIdle() {
        let timer = FocusTimer()
        XCTAssertEqual(timer.state, .idle)
        XCTAssertFalse(timer.isActive)
        XCTAssertNil(timer.phase)
        XCTAssertEqual(timer.remaining(now: start), 0)
        XCTAssertEqual(timer.progress(now: start), 0)
    }

    func testStandardDurations() {
        let standard = FocusDurations.standard
        XCTAssertEqual(standard.focus, 25 * 60)
        XCTAssertEqual(standard.shortBreak, 5 * 60)
        XCTAssertEqual(standard.longBreak, 15 * 60)
        XCTAssertEqual(standard.roundsBeforeLongBreak, 4)
    }

    func testFocusCountsDownByEndTime() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        XCTAssertEqual(timer.phase, .focus)
        XCTAssertEqual(timer.remaining(now: at(30)), 70)
        XCTAssertEqual(timer.progress(now: at(30)), 0.3, accuracy: 0.0001)
    }

    func testTickBeforeEndDoesNothing() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        XCTAssertNil(timer.tick(now: at(99)))
        XCTAssertEqual(timer.state, .running(.focus, endsAt: at(100)))
    }

    func testFocusEndWaitsForUser() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        XCTAssertEqual(timer.tick(now: at(100)), .focusEnded)
        XCTAssertEqual(timer.state, .finished(.focus, at: at(100)))
        XCTAssertEqual(timer.completedFocusRounds, 1)
        XCTAssertEqual(timer.progress(now: at(100)), 1)
        // 到点后不会自己进入下一段
        XCTAssertNil(timer.tick(now: at(500)))
        XCTAssertEqual(timer.state, .finished(.focus, at: at(100)))
    }

    /// 合盖很久再打开：一次 tick 就能发现已经过点，结束时间记的是原本该结束的时间
    func testLongSleepIsDetectedOnWake() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        XCTAssertEqual(timer.tick(now: at(3600)), .focusEnded)
        XCTAssertEqual(timer.state, .finished(.focus, at: at(100)))
    }

    func testBreakFollowsFocus() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        _ = timer.tick(now: at(100))
        timer.startBreak(now: at(110))
        XCTAssertEqual(timer.state, .running(.shortBreak, endsAt: at(130)))
        XCTAssertEqual(timer.tick(now: at(130)), .breakEnded)
        XCTAssertEqual(timer.state, .finished(.shortBreak, at: at(130)))
    }

    func testLongBreakAfterConfiguredRounds() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        _ = timer.tick(now: at(100))
        XCTAssertEqual(timer.nextBreakPhase, .shortBreak)
        timer.startBreak(now: at(100))
        _ = timer.tick(now: at(120))
        timer.startFocus(now: at(120))
        _ = timer.tick(now: at(220))
        XCTAssertEqual(timer.completedFocusRounds, 2)
        XCTAssertEqual(timer.nextBreakPhase, .longBreak)
        timer.startBreak(now: at(220))
        XCTAssertEqual(timer.state, .running(.longBreak, endsAt: at(270)))
    }

    func testPauseFreezesRemainingTime() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        timer.pause(now: at(40))
        XCTAssertTrue(timer.isPaused)
        XCTAssertEqual(timer.remaining(now: at(1000)), 60)
        XCTAssertNil(timer.tick(now: at(1000)))
        timer.resume(now: at(1000))
        XCTAssertEqual(timer.state, .running(.focus, endsAt: at(1060)))
    }

    func testPauseAndResumeIgnoredInWrongState() {
        var timer = FocusTimer(durations: short)
        timer.pause(now: start)
        XCTAssertEqual(timer.state, .idle)
        timer.startFocus(now: start)
        timer.resume(now: at(10))
        XCTAssertEqual(timer.state, .running(.focus, endsAt: at(100)))
    }

    func testExtendWhileRunning() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        timer.extend(by: 50, now: at(10))
        XCTAssertEqual(timer.state, .running(.focus, endsAt: at(150)))
        XCTAssertEqual(timer.currentLength, 150)
    }

    /// "再专注 5 分钟"：还是同一个专注，到点时不能算成两个
    func testExtendAfterFocusEndDoesNotDoubleCount() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        _ = timer.tick(now: at(100))
        timer.extend(by: 30, now: at(105))
        XCTAssertEqual(timer.state, .running(.focus, endsAt: at(135)))
        XCTAssertEqual(timer.completedFocusRounds, 0)
        XCTAssertEqual(timer.currentLength, 30)
        XCTAssertEqual(timer.tick(now: at(135)), .focusEnded)
        XCTAssertEqual(timer.completedFocusRounds, 1)
    }

    func testExtendBreakAfterItEnds() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        _ = timer.tick(now: at(100))
        timer.startBreak(now: at(100))
        _ = timer.tick(now: at(120))
        timer.extend(by: 20, now: at(125))
        XCTAssertEqual(timer.state, .running(.shortBreak, endsAt: at(145)))
        XCTAssertEqual(timer.completedFocusRounds, 1)
    }

    func testSkipBreakFromFocusEnd() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        _ = timer.tick(now: at(100))
        timer.skipBreak(now: at(110))
        XCTAssertEqual(timer.state, .finished(.shortBreak, at: at(110)))
        XCTAssertEqual(timer.completedFocusRounds, 1)
    }

    func testSkipBreakWhileResting() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        _ = timer.tick(now: at(100))
        timer.startBreak(now: at(100))
        timer.skipBreak(now: at(105))
        XCTAssertEqual(timer.state, .finished(.shortBreak, at: at(105)))
    }

    func testSkipBreakIgnoredDuringFocus() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        timer.skipBreak(now: at(10))
        XCTAssertEqual(timer.state, .running(.focus, endsAt: at(100)))
    }

    func testStopResetsEverything() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        _ = timer.tick(now: at(100))
        timer.stop()
        XCTAssertEqual(timer.state, .idle)
        XCTAssertEqual(timer.completedFocusRounds, 0)
        XCTAssertEqual(timer.progress(now: at(100)), 0)
    }

    /// 用户把系统时间往回调：剩余时间不会比这一段还长，进度不会变成负数
    func testClockSetBackwardsIsClamped() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        XCTAssertEqual(timer.remaining(now: at(-500)), 100)
        XCTAssertEqual(timer.progress(now: at(-500)), 0)
    }

    func testNewDurationsApplyToNextPhase() {
        var timer = FocusTimer(durations: short)
        timer.startFocus(now: start)
        timer.durations = FocusDurations(focus: 10, shortBreak: 5, longBreak: 7)
        XCTAssertEqual(timer.state, .running(.focus, endsAt: at(100)))
        _ = timer.tick(now: at(100))
        timer.startFocus(now: at(100))
        XCTAssertEqual(timer.state, .running(.focus, endsAt: at(110)))
    }

    func testRoundsBeforeLongBreakIsAtLeastOne() {
        XCTAssertEqual(FocusDurations(focus: 1, shortBreak: 1, longBreak: 1, roundsBeforeLongBreak: 0).roundsBeforeLongBreak, 1)
    }
}

final class FocusClockTextTests: XCTestCase {
    func testMinutesAndSeconds() {
        XCTAssertEqual(FocusClockText.format(25 * 60), "25:00")
        XCTAssertEqual(FocusClockText.format(4 * 60 + 5), "4:05")
        XCTAssertEqual(FocusClockText.format(0), "0:00")
    }

    func testRoundsUpSoTheLastSecondShows() {
        XCTAssertEqual(FocusClockText.format(0.2), "0:01")
        XCTAssertEqual(FocusClockText.format(59.5), "1:00")
    }

    func testHours() {
        XCTAssertEqual(FocusClockText.format(3600), "1:00:00")
        XCTAssertEqual(FocusClockText.format(3661), "1:01:01")
    }

    func testNegativeShowsZero() {
        XCTAssertEqual(FocusClockText.format(-5), "0:00")
    }
}

final class BreakEscalationTests: XCTestCase {
    private let finished = Date(timeIntervalSince1970: 2_000_000)

    func testCoverScreenOnlyWhenAllowed() {
        XCTAssertTrue(BreakEscalation.shouldCoverScreen(style: .coverScreen, meetingMode: false, frontmostIsFullScreen: false))
        XCTAssertTrue(BreakEscalation.shouldCoverScreen(style: .coverScreenFirmly, meetingMode: false, frontmostIsFullScreen: false))
        XCTAssertFalse(BreakEscalation.shouldCoverScreen(style: .clockOnly, meetingMode: false, frontmostIsFullScreen: false))
        XCTAssertFalse(BreakEscalation.shouldCoverScreen(style: .coverScreen, meetingMode: true, frontmostIsFullScreen: false))
        XCTAssertFalse(BreakEscalation.shouldCoverScreen(style: .coverScreen, meetingMode: false, frontmostIsFullScreen: true))
    }

    func testAutoBreakAfterWaiting() {
        let later = finished.addingTimeInterval(BreakEscalation.waitBeforeAutoBreak)
        XCTAssertFalse(BreakEscalation.shouldAutoStartBreak(
            finishedAt: finished, now: later.addingTimeInterval(-1),
            style: .coverScreen, meetingMode: false, frontmostIsFullScreen: false
        ))
        XCTAssertTrue(BreakEscalation.shouldAutoStartBreak(
            finishedAt: finished, now: later,
            style: .coverScreen, meetingMode: false, frontmostIsFullScreen: false
        ))
    }

    /// 只用小时钟、开会、全屏时，等多久都不自动开始休息
    func testNoAutoBreakWhenScreenWillNotBeCovered() {
        let muchLater = finished.addingTimeInterval(3600)
        XCTAssertFalse(BreakEscalation.shouldAutoStartBreak(
            finishedAt: finished, now: muchLater, style: .clockOnly, meetingMode: false, frontmostIsFullScreen: false
        ))
        XCTAssertFalse(BreakEscalation.shouldAutoStartBreak(
            finishedAt: finished, now: muchLater, style: .coverScreen, meetingMode: true, frontmostIsFullScreen: false
        ))
        XCTAssertFalse(BreakEscalation.shouldAutoStartBreak(
            finishedAt: finished, now: muchLater, style: .coverScreen, meetingMode: false, frontmostIsFullScreen: true
        ))
    }

    func testSkipDelay() {
        XCTAssertEqual(BreakReminderStyle.coverScreenFirmly.skipDelay, 10)
        XCTAssertEqual(BreakReminderStyle.coverScreen.skipDelay, 0)
        XCTAssertEqual(BreakReminderStyle.defaultValue, .coverScreen)
    }
}

final class FocusDurationOptionsTests: XCTestCase {
    func testDefaultsAreInTheLists() {
        XCTAssertTrue(FocusDurationOptions.focusMinutes.contains(FocusDurationOptions.defaultFocusMinutes))
        XCTAssertTrue(FocusDurationOptions.shortBreakMinutes.contains(FocusDurationOptions.defaultShortBreakMinutes))
        XCTAssertTrue(FocusDurationOptions.longBreakMinutes.contains(FocusDurationOptions.defaultLongBreakMinutes))
    }

    func testLabels() {
        XCTAssertEqual(FocusDurationOptions.label(minutes: 25), "25 分钟")
        XCTAssertEqual(FocusDurationOptions.label(minutes: 1), "1 分钟（测试用）")
    }
}

final class RestTipsTests: XCTestCase {
    func testTipsRotateAndWrap() {
        XCTAssertEqual(RestTips.tip(for: 0), RestTips.all[0])
        XCTAssertEqual(RestTips.tip(for: RestTips.all.count), RestTips.all[0])
        XCTAssertEqual(RestTips.tip(for: -1), RestTips.all[RestTips.all.count - 1])
        XCTAssertNotEqual(RestTips.tip(for: 0), RestTips.tip(for: 1))
    }
}
