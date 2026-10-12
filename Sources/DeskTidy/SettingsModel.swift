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

    @Published var petEnabled: Bool {
        didSet { settings.petEnabled = petEnabled }
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

    private var idleReminderShownThisLaunch = false

    var recoveredFromCorruptData: Bool { settings.recoveredFromCorruptData }

    init() {
        soundEnabled = settings.soundEnabled
        petEnabled = settings.petEnabled
        cleanSound = CleanSound.resolve(settings.cleanSound, fileExists: FileManager.default.fileExists(atPath:))
            ?? settings.cleanSound
        idleThreshold = settings.idleThreshold
        idleReminderFrequency = settings.idleReminderFrequency
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
