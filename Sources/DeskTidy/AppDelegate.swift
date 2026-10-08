import AppKit
import SwiftUI
import DeskTidyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let runningApps = RunningAppsModel()
    private let frontmostApp = FrontmostAppModel()
    private let scenes = SceneModel()
    private lazy var cleanup = CleanupController(runningApps: runningApps, frontmostApp: frontmostApp)

    func applicationDidFinishLaunching(_ notification: Notification) {
        runningApps.refresh()
        let panel = PanelView(
            runningApps: runningApps,
            frontmostApp: frontmostApp,
            cleanup: cleanup,
            scenes: scenes,
            onClean: { [weak self] in self?.performClean() },
            onRestore: { [weak self] in self?.performRestore() },
            onBringBack: { [weak self] app in self?.performBringBack(app) }
        )
        let host = NSHostingController(rootView: panel)
        // 列表长短变化时，面板跟着自动调整高度
        host.sizingOptions = [.preferredContentSize]
        popover.contentViewController = host
        popover.behavior = .transient

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: AppInfo.displayName)
            button.title = " 清理"
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePanel)
        }
        statusItem = item

        print("\(AppInfo.displayName) \(AppInfo.version) 已启动，请看屏幕右上角菜单栏里写着「清理」的图标。")
    }

    private func performClean() {
        popover.performClose(nil)
        cleanup.clean()
    }

    private func performRestore() {
        popover.performClose(nil)
        cleanup.restore()
    }

    private func performBringBack(_ app: RunningApp) {
        popover.performClose(nil)
        cleanup.bringBack(app)
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            runningApps.refresh()
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
