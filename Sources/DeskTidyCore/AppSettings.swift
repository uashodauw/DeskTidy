import Foundation

/// 用户的偏好设置，存在 UserDefaults 里，重启后还在。
/// 每项设置都是一个简单的值；读到类型不对或不认识的值时，删掉它，用回默认值。
public final class AppSettings {
    static let soundEnabledKey = "soundEnabled"
    static let idleThresholdKey = "idleThresholdSeconds"
    static let idleReminderFrequencyKey = "idleReminderFrequency"
    static let idleReminderLastShownKey = "idleReminderLastShown"
    static let cleanSoundKey = "cleanSound"
    static let welcomeShownKey = "welcomeShown"

    private let defaults: UserDefaults
    /// 有设置读不出来、已经换回默认值时为 true，用来提示用户一次。
    public private(set) var recoveredFromCorruptData = false

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let value = defaults.object(forKey: Self.soundEnabledKey), value as? Bool == nil {
            discard(Self.soundEnabledKey)
        }
        if let value = defaults.object(forKey: Self.idleThresholdKey),
           (value as? Int).flatMap(IdleThreshold.init(rawValue:)) == nil {
            discard(Self.idleThresholdKey)
        }
        if let value = defaults.object(forKey: Self.idleReminderFrequencyKey),
           (value as? String).flatMap(IdleReminderFrequency.init(rawValue:)) == nil {
            discard(Self.idleReminderFrequencyKey)
        }
        if let value = defaults.object(forKey: Self.cleanSoundKey),
           (value as? String).flatMap(CleanSound.init(rawValue:)) == nil {
            discard(Self.cleanSoundKey)
        }
        // 上次提醒时间坏了不值得打扰用户，悄悄删掉即可，最多就是多提醒一次
        if let value = defaults.object(forKey: Self.idleReminderLastShownKey), value as? Double == nil {
            defaults.removeObject(forKey: Self.idleReminderLastShownKey)
        }
        // 同理：坏了最多再显示一次欢迎窗口
        if let value = defaults.object(forKey: Self.welcomeShownKey), value as? Bool == nil {
            defaults.removeObject(forKey: Self.welcomeShownKey)
        }
    }

    /// 第一次打开时的欢迎窗口是否已经显示过。只显示一次。
    public var welcomeShown: Bool {
        get { defaults.object(forKey: Self.welcomeShownKey) as? Bool ?? false }
        set { defaults.set(newValue, forKey: Self.welcomeShownKey) }
    }

    /// 清理时是否播放提示音。没设置过时默认打开。
    public var soundEnabled: Bool {
        get { defaults.object(forKey: Self.soundEnabledKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.soundEnabledKey) }
    }

    /// 清理时播放哪个声音。没设置过时默认用 iPhone 发送邮件的"嗖"。
    public var cleanSound: CleanSound {
        get {
            (defaults.object(forKey: Self.cleanSoundKey) as? String).flatMap(CleanSound.init(rawValue:)) ?? .defaultValue
        }
        set { defaults.set(newValue.rawValue, forKey: Self.cleanSoundKey) }
    }

    /// 多久没用算"很久"。没设置过或存的值不认识时用默认值 1 小时。
    public var idleThreshold: IdleThreshold {
        get {
            (defaults.object(forKey: Self.idleThresholdKey) as? Int).flatMap(IdleThreshold.init(rawValue:))
                ?? .defaultValue
        }
        set { defaults.set(newValue.rawValue, forKey: Self.idleThresholdKey) }
    }

    /// "很久没用"窗口多久最多弹一次。没设置过时默认每天最多一次。
    public var idleReminderFrequency: IdleReminderFrequency {
        get {
            (defaults.object(forKey: Self.idleReminderFrequencyKey) as? String)
                .flatMap(IdleReminderFrequency.init(rawValue:)) ?? .defaultValue
        }
        set { defaults.set(newValue.rawValue, forKey: Self.idleReminderFrequencyKey) }
    }

    /// 上次弹出"很久没用"窗口的时间，存下来是为了重启后也不会马上再弹。
    public var idleReminderLastShown: Date? {
        get {
            (defaults.object(forKey: Self.idleReminderLastShownKey) as? Double)
                .map { Date(timeIntervalSince1970: $0) }
        }
        set {
            if let newValue {
                defaults.set(newValue.timeIntervalSince1970, forKey: Self.idleReminderLastShownKey)
            } else {
                defaults.removeObject(forKey: Self.idleReminderLastShownKey)
            }
        }
    }

    private func discard(_ key: String) {
        defaults.removeObject(forKey: key)
        recoveredFromCorruptData = true
    }
}
