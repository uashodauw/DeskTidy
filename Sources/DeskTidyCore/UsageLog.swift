import Foundation

/// 记录每个应用最后一次被使用的时间，存在 UserDefaults 里，重启后还在。
/// 系统不提供这个信息，只能靠本应用运行期间自己记。
public final class UsageLog {
    static let key = "lastUsedTimes"

    private let defaults: UserDefaults
    private var times: [String: Double]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode([String: Double].self, from: data) {
            times = saved
        } else {
            times = [:]
        }
    }

    public func recordUse(of bundleID: String, at date: Date = Date()) {
        times[bundleID] = date.timeIntervalSince1970
        if let data = try? JSONEncoder().encode(times) {
            defaults.set(data, forKey: Self.key)
        }
    }

    public func lastUsed(_ bundleID: String) -> Date? {
        times[bundleID].map { Date(timeIntervalSince1970: $0) }
    }
}

public enum RelativeTime {
    /// 把"上次使用的时间"说成人话：刚刚、3 分钟前、2 小时前、5 天前。
    public static func describe(_ date: Date, now: Date = Date()) -> String {
        let minutes = Int(max(0, now.timeIntervalSince(date)) / 60)
        if minutes < 1 { return "刚刚" }
        if minutes < 60 { return "\(minutes) 分钟前" }
        let hours = minutes / 60
        if hours < 24 { return "\(hours) 小时前" }
        return "\(hours / 24) 天前"
    }
}
