import AppKit
import SwiftUI
import DeskTidyCore

/// 番茄钟的计时器，界面从这里读剩余时间。
/// 每秒刷新一次 now；只有显示时间的小视图才订阅它，面板的其他部分不会跟着每秒重画（列表滚动才不会卡）。
final class FocusModel: ObservableObject {
    @Published private(set) var timer: FocusTimer
    @Published private(set) var now = Date()

    /// 一段到点了（专注结束 / 休息结束）
    var onEvent: ((FocusTimer.Event) -> Void)?
    /// 状态或时间变了：菜单栏图标、小时钟、休息玻璃跟着更新
    var onChange: (() -> Void)?

    private var ticker: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(durations: FocusDurations = .standard) {
        timer = FocusTimer(durations: durations)
        // 合盖、锁屏时计时器停了；一醒来马上对一次时间，过点了就立刻提醒
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.tick() }
    }

    deinit {
        ticker?.invalidate()
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
    }

    var remaining: TimeInterval { timer.remaining(now: now) }
    var progress: Double { timer.progress(now: now) }
    var remainingText: String { FocusClockText.format(remaining) }

    var focusMinutes: Int { Int(timer.durations.focus / 60) }

    func setDurations(_ durations: FocusDurations) {
        timer.durations = durations
    }

    func startFocus() { update { $0.startFocus(now: $1) } }
    func startBreak() { update { $0.startBreak(now: $1) } }
    func pause() { update { $0.pause(now: $1) } }
    func resume() { update { $0.resume(now: $1) } }
    func skipBreak() { update { $0.skipBreak(now: $1) } }
    func stop() { update { timer, _ in timer.stop() } }
    func extend(minutes: Int) { update { $0.extend(by: TimeInterval(minutes * 60), now: $1) } }

    private func update(_ change: (inout FocusTimer, Date) -> Void) {
        let current = Date()
        now = current
        change(&timer, current)
        syncTicker()
        onChange?()
    }

    /// 只在计时中才每秒刷新；没开始时一点电都不费
    private func syncTicker() {
        guard timer.isActive else {
            ticker?.invalidate()
            ticker = nil
            return
        }
        guard ticker == nil else { return }
        let ticker = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.tick() }
        ticker.tolerance = 0.1
        // common 模式：拖动小时钟、滚动列表、打开菜单时也照常走
        RunLoop.main.add(ticker, forMode: .common)
        self.ticker = ticker
    }

    private func tick() {
        guard timer.isActive else { return }
        now = Date()
        if let event = timer.tick(now: now) {
            onEvent?(event)
        }
        onChange?()
    }
}
