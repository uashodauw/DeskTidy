import Foundation

/// 桌面小猫的心情：跟着桌面上开着（没被收起）的应用数量变。
public enum PetMood: Equatable {
    /// 桌面很清爽，眯眼笑
    case happy
    /// 正常
    case calm
    /// 开太多了，晕乎乎的
    case dizzy

    public static let calmFrom = 5
    public static let dizzyFrom = 10

    /// visibleAppCount：没被收起的其他应用个数（不含 DeskTidy 自己）
    public static func from(visibleAppCount: Int) -> PetMood {
        if visibleAppCount >= dizzyFrom { return .dizzy }
        if visibleAppCount >= calmFrom { return .calm }
        return .happy
    }
}

/// 桌宠什么时候冒气泡提醒"有点乱了"：只提醒，从不自动清理；而且不能老是说，烦人。
public enum PetHintPolicy {
    public static let dizzyHintInterval: TimeInterval = 30 * 60

    public static func shouldShowDizzyHint(lastShown: Date?, now: Date) -> Bool {
        guard let lastShown else { return true }
        return now.timeIntervalSince(lastShown) >= dizzyHintInterval
    }
}
