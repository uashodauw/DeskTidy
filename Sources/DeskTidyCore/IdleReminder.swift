import Foundation

/// "这些应用很久没用了"窗口多久最多弹一次。
public enum IdleReminderFrequency: String, CaseIterable, Identifiable {
    case daily
    case hourly
    case oncePerLaunch
    case everyCleanup

    public static let defaultValue = IdleReminderFrequency.daily

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .daily: return "每天最多一次"
        case .hourly: return "每小时最多一次"
        case .oncePerLaunch: return "每次启动只提醒一次"
        case .everyCleanup: return "每次清理都提醒（测试用）"
        }
    }
}

public enum IdleReminderPolicy {
    /// 有很久没用的应用时，这次清理要不要弹窗提醒。
    public static func shouldRemind(
        frequency: IdleReminderFrequency,
        lastShown: Date?,
        shownThisLaunch: Bool,
        now: Date = Date()
    ) -> Bool {
        switch frequency {
        case .everyCleanup:
            return true
        case .oncePerLaunch:
            return !shownThisLaunch
        case .hourly:
            return hasPassed(3600, since: lastShown, now: now)
        case .daily:
            return hasPassed(86400, since: lastShown, now: now)
        }
    }

    /// 上次提醒的时间比现在还晚（比如用户把系统时间往回调了），就当作可以再提醒。
    private static func hasPassed(_ interval: TimeInterval, since lastShown: Date?, now: Date) -> Bool {
        guard let lastShown, lastShown <= now else { return true }
        return now.timeIntervalSince(lastShown) >= interval
    }
}
