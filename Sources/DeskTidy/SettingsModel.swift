import AppKit
import DeskTidyCore

final class SettingsModel: ObservableObject {
    private let settings = AppSettings()

    /// 这台电脑上找得到文件的系统音效，设置里只列这些。
    let availableCleanSounds = CleanSound.available(fileExists: FileManager.default.fileExists(atPath:))
    /// 选好后先读进来，清理时直接播放，不会有延迟
    private var loadedCleanSound: NSSound?

    @Published var soundEnabled: Bool {
        didSet { settings.soundEnabled = soundEnabled }
    }

    /// 换声音时马上试听一次
    @Published var cleanSound: CleanSound {
        didSet {
            guard cleanSound != oldValue else { return }
            settings.cleanSound = cleanSound
            loadCleanSound()
            playCleanSound()
        }
    }

    @Published var idleThreshold: IdleThreshold {
        didSet { settings.idleThreshold = idleThreshold }
    }

    @Published var idleReminderFrequency: IdleReminderFrequency {
        didSet { settings.idleReminderFrequency = idleReminderFrequency }
    }

    /// 番茄钟的设置变了：计时器换成新时长，小时钟按新设置显示或收起
    var onFocusSettingsChange: (() -> Void)?

    @Published var focusMinutes: Int {
        didSet { settings.focusMinutes = focusMinutes; onFocusSettingsChange?() }
    }

    @Published var shortBreakMinutes: Int {
        didSet { settings.shortBreakMinutes = shortBreakMinutes; onFocusSettingsChange?() }
    }

    @Published var longBreakMinutes: Int {
        didSet { settings.longBreakMinutes = longBreakMinutes; onFocusSettingsChange?() }
    }

    @Published var breakReminderStyle: BreakReminderStyle {
        didSet { settings.breakReminderStyle = breakReminderStyle; onFocusSettingsChange?() }
    }

    @Published var showsFocusClock: Bool {
        didSet { settings.showsFocusClock = showsFocusClock; onFocusSettingsChange?() }
    }

    /// 面板标题的颜色：跟随系统，或使用下面两种自定义颜色
    @Published var titleColorMode: TitleColorMode {
        didSet { settings.titleColorMode = titleColorMode }
    }

    @Published var titleColorLight: TitleColor {
        didSet { settings.titleColorLight = titleColorLight }
    }

    @Published var titleColorDark: TitleColor {
        didSet { settings.titleColorDark = titleColorDark }
    }

    var focusDurations: FocusDurations { settings.focusDurations }

    private var idleReminderShownThisLaunch = false

    var recoveredFromCorruptData: Bool { settings.recoveredFromCorruptData }

    init() {
        soundEnabled = settings.soundEnabled
        cleanSound = CleanSound.resolve(settings.cleanSound, fileExists: FileManager.default.fileExists(atPath:))
            ?? settings.cleanSound
        idleThreshold = settings.idleThreshold
        idleReminderFrequency = settings.idleReminderFrequency
        focusMinutes = settings.focusMinutes
        shortBreakMinutes = settings.shortBreakMinutes
        longBreakMinutes = settings.longBreakMinutes
        breakReminderStyle = settings.breakReminderStyle
        showsFocusClock = settings.showsFocusClock
        titleColorMode = settings.titleColorMode
        titleColorLight = settings.titleColorLight
        titleColorDark = settings.titleColorDark
        loadCleanSound()
    }

    var shouldShowIdleReminder: Bool {
        IdleReminderPolicy.shouldRemind(
            frequency: idleReminderFrequency,
            lastShown: settings.idleReminderLastShown,
            shownThisLaunch: idleReminderShownThisLaunch
        )
    }

    func noteIdleReminderShown() {
        idleReminderShownThisLaunch = true
        settings.idleReminderLastShown = Date()
    }

    var welcomeShown: Bool {
        get { settings.welcomeShown }
        set { settings.welcomeShown = newValue }
    }

    func playCleanSoundIfEnabled() {
        guard soundEnabled else { return }
        playCleanSound()
    }

    private func playCleanSound() {
        guard let loadedCleanSound else { return }
        loadedCleanSound.stop()
        loadedCleanSound.play()
    }

    private func loadCleanSound() {
        loadedCleanSound = cleanSound.path(fileExists: FileManager.default.fileExists(atPath:))
            .flatMap { NSSound(contentsOfFile: $0, byReference: true) }
    }
}
