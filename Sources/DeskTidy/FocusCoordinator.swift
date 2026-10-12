import AppKit
import DeskTidyCore

/// 决定番茄钟的小时钟什么时候出现、什么时候收起，到点时怎么提醒。
final class FocusCoordinator {
    private let focus: FocusModel
    private let clock: FocusClockPresenter
    /// 专注中是否显示小时钟（关掉后只在到点时出现）
    var showsClockDuringFocus: () -> Bool = { true }

    init(focus: FocusModel) {
        self.focus = focus
        clock = FocusClockPresenter(rootView: FocusClockView(focus: focus))
    }

    /// 计时器每次变化（包括每秒走一下）都会调用
    func refresh() {
        if wantsClock {
            clock.show()
        } else {
            clock.hide()
        }
    }

    func phaseEnded(_ event: FocusTimer.Event) {
        NSSound(named: event == .focusEnded ? "Glass" : "Hero")?.play()
        refresh()
        focus.requestAttention()
    }

    private var wantsClock: Bool {
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
