import AppKit
import DeskTidyCore

final class CleanupController: ObservableObject {
    @Published private(set) var record = CleanupRecord()

    private let runningApps: RunningAppsModel
    private let frontmostApp: FrontmostAppModel

    init(runningApps: RunningAppsModel, frontmostApp: FrontmostAppModel) {
        self.runningApps = runningApps
        self.frontmostApp = frontmostApp
    }

    var canRestore: Bool { !record.isEmpty }

    /// 只隐藏，不关闭：应用和它没保存的内容都还在，点 Dock 图标就能叫回来。
    func clean() {
        runningApps.refresh()
        let targets = CleanupPlanner.appsToHide(running: runningApps.apps, current: frontmostApp.current)
        for app in targets {
            NSRunningApplication(processIdentifier: app.processID)?.hide()
        }
        record.add(targets)
        // 点开面板时焦点被本应用拿走了，清理完把焦点还给用户正在用的应用
        if let current = frontmostApp.current {
            NSRunningApplication(processIdentifier: current.processID)?.activate(options: [])
        }
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
