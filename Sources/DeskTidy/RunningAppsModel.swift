import AppKit
import DeskTidyCore

final class RunningAppsModel: ObservableObject {
    @Published private(set) var apps: [RunningApp] = []

    /// 面板每次重画都要图标；每次都向系统取原图（很大）会让面板发卡，所以缩小后存起来。
    private var iconCache: [String: NSImage] = [:]
    private let iconSize = NSSize(width: 36, height: 36)

    func refresh() {
        let candidates = NSWorkspace.shared.runningApplications.compactMap { RunningApp($0) }
        apps = RunningAppList.make(from: candidates, excludingProcessID: ProcessInfo.processInfo.processIdentifier)
        let runningIDs = Set(apps.map(\.bundleID))
        iconCache = iconCache.filter { runningIDs.contains($0.key) }
    }

    func icon(for app: RunningApp) -> NSImage? {
        if let cached = iconCache[app.bundleID] {
            return cached
        }
        guard let original = NSRunningApplication(processIdentifier: app.processID)?.icon else { return nil }
        let small = NSImage(size: iconSize, flipped: false) { rect in
            original.draw(in: rect)
            return true
        }
        iconCache[app.bundleID] = small
        return small
    }
}
