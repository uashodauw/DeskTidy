import AppKit
import DeskTidyCore

final class RunningAppsModel: ObservableObject {
    @Published private(set) var apps: [RunningApp] = []

    func refresh() {
        let candidates = NSWorkspace.shared.runningApplications.compactMap { RunningApp($0) }
        apps = RunningAppList.make(from: candidates, excludingProcessID: ProcessInfo.processInfo.processIdentifier)
    }

    func icon(for app: RunningApp) -> NSImage? {
        NSRunningApplication(processIdentifier: app.processID)?.icon
    }
}
