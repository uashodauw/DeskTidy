import AppKit
import SwiftUI
import DeskTidyCore

final class RunningAppsModel: ObservableObject {
    @Published private(set) var apps: [RunningApp] = []

    /// 面板每次重画都要图标；每次都向系统取原图（很大）会让面板发卡，所以缩小后存起来。
    private var iconCache: [String: NSImage] = [:]
    private let iconSize = NSSize(width: 36, height: 36)
    private var observers: [NSObjectProtocol] = []

    init() {
        // 应用打开、退出、被收起或恢复时自动更新列表：在面板里退出应用后那一行要自己消失，
        // 桌宠的心情也要跟着桌面上实际开着的应用变
        let center = NSWorkspace.shared.notificationCenter
        let names = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ]
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                withAnimation(TidyMotion.layout) { self?.refresh() }
            })
        }
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

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
