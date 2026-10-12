import Foundation

/// 番茄钟的一段：专注，或者休息（短休息 / 每几轮一次的长休息）。
public enum FocusPhase: String, Equatable {
    case focus
    case shortBreak
    case longBreak

    public var isBreak: Bool { self != .focus }
}

/// 每段多长。默认专注 25 分钟、休息 5 分钟，每 4 个专注之后休息 15 分钟。
public struct FocusDurations: Equatable {
    public var focus: TimeInterval
    public var shortBreak: TimeInterval
    public var longBreak: TimeInterval
    public var roundsBeforeLongBreak: Int

    public init(focus: TimeInterval, shortBreak: TimeInterval, longBreak: TimeInterval, roundsBeforeLongBreak: Int = 4) {
        self.focus = focus
        self.shortBreak = shortBreak
        self.longBreak = longBreak
        self.roundsBeforeLongBreak = max(1, roundsBeforeLongBreak)
    }

    public init(focusMinutes: Int, shortBreakMinutes: Int, longBreakMinutes: Int, roundsBeforeLongBreak: Int = 4) {
        self.init(
            focus: TimeInterval(focusMinutes * 60),
            shortBreak: TimeInterval(shortBreakMinutes * 60),
            longBreak: TimeInterval(longBreakMinutes * 60),
            roundsBeforeLongBreak: roundsBeforeLongBreak
        )
    }

    public static let standard = FocusDurations(focusMinutes: 25, shortBreakMinutes: 5, longBreakMinutes: 15)

    public func length(of phase: FocusPhase) -> TimeInterval {
        switch phase {
        case .focus: return focus
        case .shortBreak: return shortBreak
        case .longBreak: return longBreak
        }
    }
}

/// 番茄钟的计时规则。只记"几点几分结束"，不靠一秒一秒地数：
/// 合盖、锁屏时程序会被暂停，数秒会漏掉；按结束时间算，打开后剩余时间仍然准确。
///
/// 计时只会因为用户的操作而开始；到点了只是停在"已结束"等用户决定，不会自己进入下一段。
public struct FocusTimer: Equatable {
    public enum State: Equatable {
        case idle
        case running(FocusPhase, endsAt: Date)
        case paused(FocusPhase, remaining: TimeInterval)
        /// 这一段到点了，等用户决定下一步
        case finished(FocusPhase, at: Date)
    }

    public enum Event: Equatable {
        case focusEnded
        case breakEnded
    }

    public private(set) var state: State = .idle
    /// 这一组里已经完成了几个专注，每满 roundsBeforeLongBreak 个，休息长一点
    public private(set) var completedFocusRounds = 0
    /// 当前这一段的总长度，用来算进度
    public private(set) var currentLength: TimeInterval = 0
    public var durations: FocusDurations

    public init(durations: FocusDurations = .standard) {
        self.durations = durations
    }

    public var phase: FocusPhase? {
        switch state {
        case .idle: return nil
        case .running(let phase, _), .paused(let phase, _), .finished(let phase, _): return phase
        }
    }

    public var isActive: Bool { state != .idle }

    public var isPaused: Bool {
        if case .paused = state { return true }
        return false
    }

    /// 下一次休息是短的还是长的
    public var nextBreakPhase: FocusPhase {
        completedFocusRounds > 0 && completedFocusRounds % durations.roundsBeforeLongBreak == 0 ? .longBreak : .shortBreak
    }

    public mutating func startFocus(now: Date = Date()) {
        begin(.focus, now: now)
    }

    public mutating func startBreak(now: Date = Date()) {
        begin(nextBreakPhase, now: now)
    }

    public mutating func pause(now: Date = Date()) {
        guard case .running(let phase, _) = state else { return }
        state = .paused(phase, remaining: remaining(now: now))
    }

    public mutating func resume(now: Date = Date()) {
        guard case .paused(let phase, let remaining) = state else { return }
        state = .running(phase, endsAt: now.addingTimeInterval(remaining))
    }

    /// 计时中：多加一段时间。刚到点：从现在起再来一段（"再专注 5 分钟"、"再休息 5 分钟"）。
    public mutating func extend(by seconds: TimeInterval, now: Date = Date()) {
        switch state {
        case .running(let phase, let endsAt):
            state = .running(phase, endsAt: endsAt.addingTimeInterval(seconds))
            currentLength += seconds
        case .paused(let phase, let remaining):
            state = .paused(phase, remaining: remaining + seconds)
            currentLength += seconds
        case .finished(let phase, _):
            // 到点时已经算完成了一个专注；接着专注就还是同一个，不能多算
            if phase == .focus {
                completedFocusRounds = max(0, completedFocusRounds - 1)
            }
            state = .running(phase, endsAt: now.addingTimeInterval(seconds))
            currentLength = seconds
        case .idle:
            return
        }
    }

    /// 不休息了：直接停在"休息结束"，等用户开始下一轮
    public mutating func skipBreak(now: Date = Date()) {
        switch state {
        case .running(let phase, _) where phase.isBreak:
            state = .finished(phase, at: now)
        case .paused(let phase, _) where phase.isBreak:
            state = .finished(phase, at: now)
        case .finished(.focus, _):
            state = .finished(nextBreakPhase, at: now)
        default:
            return
        }
    }

    public mutating func stop() {
        state = .idle
        completedFocusRounds = 0
        currentLength = 0
    }

    /// 每秒调用一次；到点时返回发生了什么，并停在"已结束"
    public mutating func tick(now: Date = Date()) -> Event? {
        guard case .running(let phase, let endsAt) = state, now >= endsAt else { return nil }
        state = .finished(phase, at: endsAt)
        if phase == .focus {
            completedFocusRounds += 1
            return .focusEnded
        }
        return .breakEnded
    }

    /// 还剩多少秒。用户把系统时间往回调时，不会超过这一段的总长度。
    public func remaining(now: Date = Date()) -> TimeInterval {
        switch state {
        case .running(_, let endsAt): return min(max(0, endsAt.timeIntervalSince(now)), currentLength)
        case .paused(_, let remaining): return remaining
        case .idle, .finished: return 0
        }
    }

    /// 已经走了多少，0 到 1
    public func progress(now: Date = Date()) -> Double {
        switch state {
        case .idle: return 0
        case .finished: return 1
        case .running, .paused:
            guard currentLength > 0 else { return 1 }
            return min(max(1 - remaining(now: now) / currentLength, 0), 1)
        }
    }

    private mutating func begin(_ phase: FocusPhase, now: Date) {
        let length = durations.length(of: phase)
        currentLength = length
        state = .running(phase, endsAt: now.addingTimeInterval(length))
    }
}

/// 倒计时的文字：和 iPhone 锁屏上的计时一样，"24:59"、"4:05"，超过一小时是"1:00:00"。
/// 向上取整：刚开始显示 25:00，最后一秒显示 0:01，到 0:00 时正好结束。
public enum FocusClockText {
    public static func format(_ remaining: TimeInterval) -> String {
        let total = Int(max(0, remaining).rounded(.up))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

/// 设置里能选的时长（分钟）。1 分钟只是方便试一试到点提醒，标成"测试用"。
public enum FocusDurationOptions {
    public static let focusMinutes = [1, 15, 20, 25, 30, 45, 50, 60]
    public static let shortBreakMinutes = [1, 3, 5, 10, 15]
    public static let longBreakMinutes = [10, 15, 20, 30]

    public static let defaultFocusMinutes = 25
    public static let defaultShortBreakMinutes = 5
    public static let defaultLongBreakMinutes = 15

    public static func label(minutes: Int) -> String {
        minutes == 1 ? "1 分钟（测试用）" : "\(minutes) 分钟"
    }
}

/// 休息时怎么提醒
public enum BreakReminderStyle: String, CaseIterable, Identifiable {
    case clockOnly
    case coverScreen
    case coverScreenFirmly

    public static let defaultValue = BreakReminderStyle.coverScreen

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .clockOnly: return "只用小时钟提醒"
        case .coverScreen: return "铺满屏幕，随时可以跳过"
        case .coverScreenFirmly: return "铺满屏幕，前 10 秒不能跳过"
        }
    }

    public var coversScreen: Bool { self != .clockOnly }

    /// 休息开始后多久才能跳过
    public var skipDelay: TimeInterval { self == .coverScreenFirmly ? 10 : 0 }
}

/// 什么时候把休息玻璃铺满屏幕
public enum BreakEscalation {
    /// 专注到点后，用户一直没理，等这么久再自动开始休息
    public static let waitBeforeAutoBreak: TimeInterval = 60

    /// 用户正在全屏看视频、演示，或者打开了开会模式，都不铺满屏幕，只用小时钟提醒
    public static func shouldCoverScreen(style: BreakReminderStyle, meetingMode: Bool, frontmostIsFullScreen: Bool) -> Bool {
        style.coversScreen && !meetingMode && !frontmostIsFullScreen
    }

    /// 专注到点后过了多久没人理，就自动开始休息。只在会铺满屏幕时才这样做：
    /// 只用小时钟提醒时，自动开始休息用户根本看不到，等于偷偷替用户做了决定。
    public static func shouldAutoStartBreak(
        finishedAt: Date,
        now: Date,
        style: BreakReminderStyle,
        meetingMode: Bool,
        frontmostIsFullScreen: Bool
    ) -> Bool {
        guard shouldCoverScreen(style: style, meetingMode: meetingMode, frontmostIsFullScreen: frontmostIsFullScreen) else {
            return false
        }
        return now.timeIntervalSince(finishedAt) >= waitBeforeAutoBreak
    }
}

/// 休息时屏幕中间的一句话，每次休息换一句
public enum RestTips {
    public static let all = [
        "站起来走走，活动一下肩膀",
        "看看窗外远处，让眼睛放松",
        "喝口水吧",
        "闭上眼睛，慢慢深呼吸三次",
        "伸个懒腰，转转脖子",
        "离开屏幕一会儿，回来会更专注",
    ]

    public static func tip(for round: Int) -> String {
        all[((round % all.count) + all.count) % all.count]
    }
}
