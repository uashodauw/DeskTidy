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

    var recoveredFromCorruptData: Bool { settings.recoveredFromCorruptData }

    init() {
        soundEnabled = settings.soundEnabled
        idleThreshold = settings.idleThreshold
    }

    func playCleanSoundIfEnabled() {
        guard soundEnabled, let cleanSound else { return }
        cleanSound.stop()
        cleanSound.play()
    }
}
