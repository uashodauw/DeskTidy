import AppKit
import DeskTidyCore

final class CleanupController: ObservableObject {
    @Published private(set) var record = CleanupRecord()

    private let runningApps: RunningAppsModel
    private let frontmostApp: FrontmostAppModel
    private let scenes: SceneModel

    init(runningApps: RunningAppsModel, frontmostApp: FrontmostAppModel, scenes: SceneModel) {
        self.runningApps = runningApps
        self.frontmostApp = frontmostApp
        self.scenes = scenes
    }

    var canRestore: Bool { !record.isEmpty }

    /// 只隐藏，不关闭：应用和它没保存的内容都还在，点 Dock 图标就能叫回来。
    func clean() {
        runningApps.refresh()
        let targets = CleanupPlanner.appsToHide(
            running: runningApps.apps,
            current: frontmostApp.current,
            keptBundleIDs: scenes.selectedScene.keptBundleIDs
        )
        for app in targets {
            NSRunningApplication(processIdentifier: app.processID)?.hide()
        }
        record.add(targets)
        // 点开面板时焦点被本应用拿走了，清理完把焦点还给用户正在用的应用
        if let current = frontmostApp.current {
            NSRunningApplication(processIdentifier: current.processID)?.activate(options: [])
        }
    }

    /// 已收起、还没被叫回来的应用。
    func hiddenApps(in running: [RunningApp]) -> [RunningApp] {
        record.appsToRestore(running: running)
    }

    func bringBack(_ app: RunningApp) {
        let runningApp = NSRunningApplication(processIdentifier: app.processID)
        runningApp?.unhide()
        runningApp?.activate(options: [])
        record.remove(bundleID: app.bundleID)
    }

    func restore() {
        runningApps.refresh()
        for app in record.appsToRestore(running: runningApps.apps) {
            NSRunningApplication(processIdentifier: app.processID)?.unhide()
        }
        record = CleanupRecord()
        if let current = frontmostApp.current {
            NSRunningApplication(processIdentifier: current.processID)?.activate(options: [])
        }
    }
}
