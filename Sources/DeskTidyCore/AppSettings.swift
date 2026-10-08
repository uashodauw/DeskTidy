import Foundation

/// 用户的偏好设置，存在 UserDefaults 里，重启后还在。
public final class AppSettings {
    static let soundEnabledKey = "soundEnabled"

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// 清理时是否播放提示音。没设置过时默认打开。
    public var soundEnabled: Bool {
        get { defaults.object(forKey: Self.soundEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.soundEnabledKey) }
    }
}
