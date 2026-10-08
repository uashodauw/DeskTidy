import AppKit
import DeskTidyCore

final class FrontmostAppModel: ObservableObject {
    @Published private(set) var current: RunningApp?

    private var tracker: FrontmostAppTracker
    private var observers: [NSObjectProtocol] = []

    init() {
        let workspace = NSWorkspace.shared
        tracker = FrontmostAppTracker(
            ownProcessID: ProcessInfo.processInfo.processIdentifier,
            initial: workspace.frontmostApplication.flatMap { RunningApp($0) }
        )
        current = tracker.current

        let center = workspace.notificationCenter
        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let app = Self.application(in: note).flatMap({ RunningApp($0) }) else { return }
            self.tracker.appDidActivate(app)
            self.current = self.tracker.current
        })
        observers.append(center.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            guard let self, let app = Self.application(in: note) else { return }
            self.tracker.appDidTerminate(processID: app.processIdentifier)
            self.current = self.tracker.current
        })
    }

    deinit {
        for observer in observers {
            NSWorkspace.shared.notificationCenter.removeObserver(observer)
        }
    }

    private static func application(in note: Notification) -> NSRunningApplication? {
        note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
    }
}
