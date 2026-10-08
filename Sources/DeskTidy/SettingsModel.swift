import AppKit
import DeskTidyCore

final class SettingsModel: ObservableObject {
    private let settings = AppSettings()
    private let cleanSound = NSSound(named: "Pop")

    @Published var soundEnabled: Bool {
        didSet { settings.soundEnabled = soundEnabled }
    }

    init() {
        soundEnabled = settings.soundEnabled
    }

    func playCleanSoundIfEnabled() {
        guard soundEnabled, let cleanSound else { return }
        cleanSound.stop()
        cleanSound.play()
    }
}
