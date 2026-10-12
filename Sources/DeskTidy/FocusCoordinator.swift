import AppKit
import DeskTidyCore

/// 决定番茄钟的三级提醒怎么出现：
/// 专注中角落小时钟 → 到点小时钟变成卡片 → 休息时毛玻璃铺满屏幕（不方便时只用小时钟）。
final class FocusCoordinator {
    private let focus: FocusModel
    private let clock: FocusClockPresenter
    private let overlay: BreakOverlayPresenter

    /// 专注中是否显示小时钟（关掉后只在到点时出现）
    var showsClockDuringFocus: () -> Bool = { true }
    var breakStyle: () -> BreakReminderStyle = { .defaultValue }
    var meetingMode: () -> Bool = { false }

    /// 专注到点后我们真正发现的时间。合盖时到点的话，计时器记的是原本的结束时间，
    /// 打开盖子不能马上就自动开始休息，要从发现的时候起再等一会儿。
    private var focusEndNoticedAt: Date?
    /// 这次休息要不要铺满屏幕，休息开始时决定一次，中途不变
    private var currentBreakCovers: Bool?
    private var breaksTaken = 0

    init(focus: FocusModel) {
        self.focus = focus
        clock = FocusClockPresenter(rootView: FocusClockView(focus: focus))
        overlay = BreakOverlayPresenter(focus: focus)
        overlay.onSkip = { [weak focus] in focus?.skipBreak() }
    }

    /// 计时器每次变化（包括每秒走一下）都会调用
    func refresh() {
        autoStartBreakIfIgnored()
        updateOverlay()
        if wantsClock {
            clock.show()
        } else {
            clock.hide()
        }
    }

    func phaseEnded(_ event: FocusTimer.Event) {
        if event == .focusEnded {
            focusEndNoticedAt = Date()
        }
        NSSound(named: event == .focusEnded ? "Glass" : "Hero")?.play()
        refresh()
        focus.requestAttention()
    }

    /// 专注到点后一直没人理，过一会儿自动开始休息。不方便铺满屏幕时不这样做，只留着小时钟提醒。
    private func autoStartBreakIfIgnored() {
        guard case .finished(.focus, _) = focus.timer.state, let noticedAt = focusEndNoticedAt else { return }
        // 先看时间够不够：没到时间就不用每秒都去查有没有全屏应用
        guard Date().timeIntervalSince(noticedAt) >= BreakEscalation.waitBeforeAutoBreak else { return }
        if BreakEscalation.shouldAutoStartBreak(
            finishedAt: noticedAt,
            now: Date(),
            style: breakStyle(),
            meetingMode: meetingMode(),
            frontmostIsFullScreen: FullScreenDetector.frontmostAppIsFullScreen()
        ) {
            focus.startBreak()
        }
    }

    private func updateOverlay() {
        guard let phase = focus.timer.phase, phase.isBreak, !isFinished else {
            currentBreakCovers = nil
            overlay.hide()
            return
        }
        if currentBreakCovers == nil {
            let covers = BreakEscalation.shouldCoverScreen(
                style: breakStyle(),
                meetingMode: meetingMode(),
                frontmostIsFullScreen: FullScreenDetector.frontmostAppIsFullScreen()
            )
            currentBreakCovers = covers
            if covers {
                breaksTaken += 1
                overlay.show(tip: RestTips.tip(for: breaksTaken - 1), skipDelay: breakStyle().skipDelay)
            }
        }
    }

    private var isFinished: Bool {
        if case .finished = focus.timer.state { return true }
        return false
    }

    private var wantsClock: Bool {
        if overlay.isShown { return false }
        switch focus.timer.state {
        case .idle:
            return false
        case .finished:
            return true
        case .running(let phase, _), .paused(let phase, _):
            return phase.isBreak || showsClockDuringFocus()
        }
    }
}
