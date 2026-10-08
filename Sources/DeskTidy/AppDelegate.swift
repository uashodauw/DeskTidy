import AppKit
import KeyboardShortcuts
import SwiftUI
import DeskTidyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var panel: GlassPanelPresenter?
    private let runningApps = RunningAppsModel()
    private let frontmostApp = FrontmostAppModel()
    private let scenes = SceneModel()
    private let toast = ToastPresenter()
    private let settings = SettingsModel()
    private let usage = UsageModel()
    private let idleApps = IdleAppsPresenter()
    private lazy var cleanup = CleanupController(runningApps: runningApps, frontmostApp: frontmostApp, scenes: scenes)

    func applicationDidFinishLaunching(_ notification: Notification) {
        runningApps.refresh()
        usage.noteSeen(runningApps.apps)
        panel = GlassPanelPresenter(rootView: PanelView(
            runningApps: runningApps,
            frontmostApp: frontmostApp,
            cleanup: cleanup,
            scenes: scenes,
            settings: settings,
            usage: usage,
            onClean: { [weak self] in self?.performClean() },
            onRestore: { [weak self] in self?.performRestore() },
            onBringBack: { [weak self] app in self?.performBringBack(app) }
        ))

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: AppInfo.displayName)
            button.title = " 清理"
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePanel)
        }
        statusItem = item

        KeyboardShortcuts.onKeyUp(for: .cleanDesktop) { [weak self] in
            self?.performClean()
        }

        print("\(AppInfo.displayName) \(AppInfo.version) 已启动，请看屏幕右上角菜单栏里写着「清理」的图标。")

        if scenes.recoveredFromCorruptData || settings.recoveredFromCorruptData {
            // 等菜单栏图标先出来，再弹提示
            DispatchQueue.main.async { [weak self] in self?.showRecoveredNotice() }
        }
    }

    private func showRecoveredNotice() {
        let alert = NSAlert()
        alert.messageText = "设置已恢复为默认"
        alert.informativeText = "保存的场景或设置读不出来了，\(AppInfo.displayName) 已经换回默认设置。你的应用和文件都没有受影响。"
        alert.addButton(withTitle: "好的")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func performClean() {
        panel?.close()
        let hiddenCount = cleanup.clean()
        toast.show(CleanupFeedback(hiddenCount: hiddenCount))
        settings.playCleanSoundIfEnabled()
        showIdleApps()
    }

    private func showIdleApps() {
        usage.noteSeen(runningApps.apps)
        let threshold = settings.idleThreshold
        let idle = IdleAppFinder.idleApps(
            running: runningApps.apps,
            current: frontmostApp.current,
            keptBundleIDs: scenes.keptBundleIDs,
            lastUsed: usage.lastUsed,
            threshold: threshold.seconds
        )
        guard !idle.isEmpty else {
            idleApps.close()
            return
        }
        guard settings.shouldShowIdleReminder else { return }
        settings.noteIdleReminderShown()
        idleApps.show(IdleAppsView(
            apps: idle,
            threshold: threshold,
            icon: runningApps.icon(for:),
            lastUsed: usage.lastUsed,
            onQuit: { [weak self] apps in
                self?.idleApps.close()
                self?.cleanup.politelyQuit(apps)
            },
            onDismiss: { [weak self] in self?.idleApps.close() }
        ))
    }

    private func performRestore() {
        panel?.close()
        cleanup.restore()
    }

    private func performBringBack(_ app: RunningApp) {
        panel?.close()
        cleanup.bringBack(app)
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        guard let panel else { return }
        if panel.isShown {
            panel.close()
        } else {
            runningApps.refresh()
            usage.noteSeen(runningApps.apps)
            panel.show(below: button)
        }
    }
}
