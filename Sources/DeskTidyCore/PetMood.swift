/// 面板上小桌宠的心情：跟着桌面上开着（没被收起）的应用数量变。
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
