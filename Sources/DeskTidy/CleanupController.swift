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

    /// 收起/恢复要挨个通知每个应用，应用一多会卡住界面，所以放到后台做。
    /// 用同一条串行队列：连续点清理和恢复时，动作按点击顺序执行，不会乱。
    private let appActions = DispatchQueue(label: "DeskTidy.appActions", qos: .userInitiated)

    var canRestore: Bool { !record.isEmpty }

    /// 只隐藏，不关闭：应用和它没保存的内容都还在，点 Dock 图标就能叫回来。
    /// 立刻返回这次要隐藏几个应用，让提示马上出来；真正的隐藏在后台进行。
    @discardableResult
    func clean() -> Int {
        runningApps.refresh()
        let targets = CleanupPlanner.appsToHide(
            running: runningApps.apps,
            current: frontmostApp.current,
            keptBundleIDs: scenes.keptBundleIDs
        )
        record.add(targets)
        run(on: targets.map(\.processID), returningFocusTo: frontmostApp.current) { $0.hide() }
        return targets.count
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

    /// 只用普通退出，绝不能改成 forceTerminate：普通退出时，有没保存内容的应用会先问用户要不要保存。
    /// 退出前先取消隐藏，否则"是否保存"的询问会出现在看不见的窗口上。
    func politelyQuit(_ apps: [RunningApp]) {
        for app in apps {
            let runningApp = NSRunningApplication(processIdentifier: app.processID)
            runningApp?.unhide()
            runningApp?.terminate()
            record.remove(bundleID: app.bundleID)
        }
    }

    func restore() {
        runningApps.refresh()
        let targets = record.appsToRestore(running: runningApps.apps)
        record = CleanupRecord()
        run(on: targets.map(\.processID), returningFocusTo: frontmostApp.current) { $0.unhide() }
    }

    /// 点开面板时焦点被本应用拿走了，做完后把焦点还给用户正在用的应用。
    private func run(
        on processIDs: [Int32],
        returningFocusTo current: RunningApp?,
        _ action: @escaping (NSRunningApplication) -> Void
    ) {
        appActions.async {
            for processID in processIDs {
                if let app = NSRunningApplication(processIdentifier: processID) {
                    action(app)
                }
            }
            DispatchQueue.main.async {
                if let current {
                    NSRunningApplication(processIdentifier: current.processID)?.activate(options: [])
                }
            }
        }
    }
}
