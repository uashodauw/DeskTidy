import AppKit
import DeskTidyCore

/// 切进和离开一个应用时都记一次时间：只记切进去的时间，会把连续用了很久的应用误判为"很久没用"。
final class UsageModel {
    private let log = UsageLog()
    private let ownProcessID = ProcessInfo.processInfo.processIdentifier
    private var observers: [NSObjectProtocol] = []

    init() {
        if let frontmost = NSWorkspace.shared.frontmostApplication {
            record(frontmost)
        }
        let center = NSWorkspace.shared.notificationCenter
        for name in [NSWorkspace.didActivateApplicationNotification, NSWorkspace.didDeactivateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] note in
                guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
                self?.record(app)
            })
        }
    }

    deinit {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    func lastUsed(_ app: RunningApp) -> Date? {
        log.lastUsed(app.bundleID)
    }

    private func record(_ app: NSRunningApplication) {
        guard app.processIdentifier != ownProcessID, let runningApp = RunningApp(app) else { return }
        log.recordUse(of: runningApp.bundleID)
    }
}
