import AppKit
import DeskTidyCore

final class SettingsModel: ObservableObject {
    private let settings = AppSettings()
    private let cleanSound = NSSound(named: "Pop")

    @Published var soundEnabled: Bool {
        didSet { settings.soundEnabled = soundEnabled }
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
        idleThreshold = settings.idleThreshold
        idleReminderFrequency = settings.idleReminderFrequency
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

    func playCleanSoundIfEnabled() {
        guard soundEnabled, let cleanSound else { return }
        cleanSound.stop()
        cleanSound.play()
    }
}
