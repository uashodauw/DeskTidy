import Foundation

/// "多久没用算很久"的可选项。
public enum IdleThreshold: Int, CaseIterable, Identifiable {
    case oneMinute = 60
    case thirtyMinutes = 1800
    case oneHour = 3600
    case twoHours = 7200

    public static let defaultValue = IdleThreshold.oneHour

    public var id: Int { rawValue }
    public var seconds: TimeInterval { TimeInterval(rawValue) }

    public var shortLabel: String {
        switch self {
        case .oneMinute: return "1 分钟"
        case .thirtyMinutes: return "30 分钟"
        case .oneHour: return "1 小时"
        case .twoHours: return "2 小时"
        }
    }

    public var label: String {
        self == .oneMinute ? "\(shortLabel)（测试用）" : shortLabel
    }
}

public enum IdleAppFinder {
    /// 超过 threshold 没用过的应用。当前在用的、场景里的应用永远不算。
    /// 没有使用记录的应用也不算：不知道它多久没用，就不该建议用户退出它。
    public static func idleApps(
        running: [RunningApp],
        current: RunningApp?,
        keptBundleIDs: [String],
        lastUsed: (RunningApp) -> Date?,
        now: Date = Date(),
        threshold: TimeInterval
    ) -> [RunningApp] {
        let kept = Set(keptBundleIDs)
        return running.filter { app in
            guard app.bundleID != current?.bundleID, !kept.contains(app.bundleID),
                  let lastUsedDate = lastUsed(app) else { return false }
            return now.timeIntervalSince(lastUsedDate) >= threshold
        }
    }
}
