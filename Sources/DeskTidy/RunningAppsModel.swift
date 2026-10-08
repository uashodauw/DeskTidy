import AppKit
import DeskTidyCore

final class RunningAppsModel: ObservableObject {
    @Published private(set) var apps: [RunningApp] = []

    func refresh() {
        let candidates = NSWorkspace.shared.runningApplications.compactMap { app -> RunningApp? in
            guard app.activationPolicy == .regular, let bundleID = app.bundleIdentifier else { return nil }
            return RunningApp(bundleID: bundleID, name: app.localizedName ?? bundleID, processID: app.processIdentifier)
        }
        apps = RunningAppList.make(from: candidates, excludingProcessID: ProcessInfo.processInfo.processIdentifier)
    }

    func icon(for app: RunningApp) -> NSImage? {
        NSRunningApplication(processIdentifier: app.processID)?.icon
    }
}
