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
    static let focusMinutesKey = "focusMinutes"
    static let shortBreakMinutesKey = "shortBreakMinutes"
    static let longBreakMinutesKey = "longBreakMinutes"
    static let breakReminderStyleKey = "breakReminderStyle"
    static let showsFocusClockKey = "showsFocusClock"
    static let titleColorModeKey = "titleColorMode"
    static let titleColorLightKey = "titleColorLight"
    static let titleColorDarkKey = "titleColorDark"

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
        discardUnlessAllowed(Self.focusMinutesKey, FocusDurationOptions.focusMinutes)
        discardUnlessAllowed(Self.shortBreakMinutesKey, FocusDurationOptions.shortBreakMinutes)
        discardUnlessAllowed(Self.longBreakMinutesKey, FocusDurationOptions.longBreakMinutes)
        if let value = defaults.object(forKey: Self.breakReminderStyleKey),
           (value as? String).flatMap(BreakReminderStyle.init(rawValue:)) == nil {
            discard(Self.breakReminderStyleKey)
        }
        if let value = defaults.object(forKey: Self.showsFocusClockKey), value as? Bool == nil {
            discard(Self.showsFocusClockKey)
        }
        if let value = defaults.object(forKey: Self.titleColorModeKey),
           (value as? String).flatMap(TitleColorMode.init(rawValue:)) == nil {
            discard(Self.titleColorModeKey)
        }
        discardUnlessHex(Self.titleColorLightKey)
        discardUnlessHex(Self.titleColorDarkKey)
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

    /// 番茄钟专注多少分钟。没设置过时 25 分钟。
    public var focusMinutes: Int {
        get { minutes(for: Self.focusMinutesKey, allowed: FocusDurationOptions.focusMinutes, default: FocusDurationOptions.defaultFocusMinutes) }
        set { defaults.set(newValue, forKey: Self.focusMinutesKey) }
    }

    /// 每次休息多少分钟。没设置过时 5 分钟。
    public var shortBreakMinutes: Int {
        get {
            minutes(for: Self.shortBreakMinutesKey, allowed: FocusDurationOptions.shortBreakMinutes, default: FocusDurationOptions.defaultShortBreakMinutes)
        }
        set { defaults.set(newValue, forKey: Self.shortBreakMinutesKey) }
    }

    /// 每 4 个专注之后的长休息多少分钟。没设置过时 15 分钟。
    public var longBreakMinutes: Int {
        get {
            minutes(for: Self.longBreakMinutesKey, allowed: FocusDurationOptions.longBreakMinutes, default: FocusDurationOptions.defaultLongBreakMinutes)
        }
        set { defaults.set(newValue, forKey: Self.longBreakMinutesKey) }
    }

    public var focusDurations: FocusDurations {
        FocusDurations(focusMinutes: focusMinutes, shortBreakMinutes: shortBreakMinutes, longBreakMinutes: longBreakMinutes)
    }

    /// 休息时怎么提醒。没设置过时铺满屏幕、随时可以跳过。
    public var breakReminderStyle: BreakReminderStyle {
        get {
            (defaults.object(forKey: Self.breakReminderStyleKey) as? String).flatMap(BreakReminderStyle.init(rawValue:))
                ?? .defaultValue
        }
        set { defaults.set(newValue.rawValue, forKey: Self.breakReminderStyleKey) }
    }

    /// 专注中是否在屏幕角落显示小时钟。没设置过时显示。
    public var showsFocusClock: Bool {
        get { defaults.object(forKey: Self.showsFocusClockKey) as? Bool ?? true }
        set { defaults.set(newValue, forKey: Self.showsFocusClockKey) }
    }

    /// 面板标题用设计好的两种颜色跟着系统换，还是用用户自己选的。没设置过时跟随系统。
    public var titleColorMode: TitleColorMode {
        get {
            (defaults.object(forKey: Self.titleColorModeKey) as? String).flatMap(TitleColorMode.init(rawValue:))
                ?? .followSystem
        }
        set { defaults.set(newValue.rawValue, forKey: Self.titleColorModeKey) }
    }

    /// 自定义时，浅色外观用的标题颜色。没设置过时是设计好的近黑。
    public var titleColorLight: TitleColor {
        get { storedTitleColor(Self.titleColorLightKey) ?? .lightAppearance }
        set { defaults.set(newValue.hex, forKey: Self.titleColorLightKey) }
    }

    /// 自定义时，深色外观用的标题颜色。没设置过时是设计好的纯白。
    public var titleColorDark: TitleColor {
        get { storedTitleColor(Self.titleColorDarkKey) ?? .darkAppearance }
        set { defaults.set(newValue.hex, forKey: Self.titleColorDarkKey) }
    }

    private func minutes(for key: String, allowed: [Int], default defaultValue: Int) -> Int {
        guard let value = defaults.object(forKey: key) as? Int, allowed.contains(value) else { return defaultValue }
        return value
    }

    private func storedTitleColor(_ key: String) -> TitleColor? {
        (defaults.object(forKey: key) as? String).flatMap(TitleColor.init(hex:))
    }

    private func discardUnlessHex(_ key: String) {
        guard let value = defaults.object(forKey: key) else { return }
        if let hex = value as? String, TitleColor(hex: hex) != nil { return }
        discard(key)
    }

    private func discardUnlessAllowed(_ key: String, _ allowed: [Int]) {
        guard let value = defaults.object(forKey: key) else { return }
        if let minutes = value as? Int, allowed.contains(minutes) { return }
        discard(key)
    }

    private func discard(_ key: String) {
        defaults.removeObject(forKey: key)
        recoveredFromCorruptData = true
    }
}
