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
    private let idleApps = GlassWindowPresenter(placement: .topRight)
    private let welcome = GlassWindowPresenter(placement: .center)
    private let focus = FocusModel()
    private lazy var focusCoordinator = FocusCoordinator(focus: focus)
    private lazy var settingsWindow = SettingsWindowController(scenes: scenes, settings: settings)
    private lazy var cleanup = CleanupController(runningApps: runningApps, frontmostApp: frontmostApp, scenes: scenes)

    func applicationDidFinishLaunching(_ notification: Notification) {
        runningApps.refresh()
        usage.noteSeen(runningApps.apps)
        panel = GlassPanelPresenter(rootView: PanelView(
            runningApps: runningApps,
            frontmostApp: frontmostApp,
            cleanup: cleanup,
            scenes: scenes,
            usage: usage,
            focus: focus,
            onStartFocus: { [weak self] in self?.startFocus() },
            onOpenSettings: { [weak self] in self?.openSettings() },
            onClean: { [weak self] in self?.performClean() },
            onRestore: { [weak self] in self?.performRestore() },
            onBringBack: { [weak self] app in self?.performBringBack(app) },
            onOpen: { [weak self] app in self?.performOpen(app) },
            onQuit: { [weak self] app in self?.cleanup.politelyQuit([app]) }
        ))

        // 只放图标不放文字：菜单栏放不下时，新装应用的图标最先被系统藏起来，越窄越不容易被挤掉
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = item.button {
            button.image = Self.brandIcon
            button.toolTip = Self.brandToolTip
            button.target = self
            button.action = #selector(togglePanel)
        }
        statusItem = item

        focus.onChange = { [weak self] in
            self?.updateStatusIcon()
            self?.focusCoordinator.refresh()
        }
        focus.onEvent = { [weak self] event in self?.focusCoordinator.phaseEnded(event) }
        configureFocus()

        KeyboardShortcuts.onKeyUp(for: .cleanDesktop) { [weak self] in
            self?.performClean()
        }
        KeyboardShortcuts.onKeyUp(for: .togglePanel) { [weak self] in
            self?.togglePanel()
        }

        print("\(AppInfo.displayName) \(AppInfo.version) 已启动，请看屏幕右上角菜单栏里的星星图标。")

        if scenes.recoveredFromCorruptData || settings.recoveredFromCorruptData {
            // 等菜单栏图标先出来，再弹提示
            DispatchQueue.main.async { [weak self] in self?.showRecoveredNotice() }
        }
        if !settings.welcomeShown {
            DispatchQueue.main.async { [weak self] in self?.showWelcome() }
        }
    }

    private static let brandIcon = NSImage(systemSymbolName: "sparkles", accessibilityDescription: AppInfo.displayName)
    private static var brandToolTip: String { "\(AppInfo.displayName)（\(AppInfo.brandName)）" }

    private func openSettings() {
        panel?.close()
        settingsWindow.show()
    }

    // MARK: - 番茄钟

    private func configureFocus() {
        focus.setDurations(settings.focusDurations)
        focusCoordinator.showsClockDuringFocus = { [weak self] in self?.settings.showsFocusClock ?? true }
        focusCoordinator.breakStyle = { [weak self] in self?.settings.breakReminderStyle ?? .defaultValue }
        focusCoordinator.meetingMode = { [weak self] in self?.focus.meetingMode ?? false }
        // 改了时长：正在走的这一段不变，下一段开始按新时长
        settings.onFocusSettingsChange = { [weak self] in
            guard let self else { return }
            self.focus.setDurations(self.settings.focusDurations)
            self.focusCoordinator.refresh()
        }
    }

    private func startFocus() {
        panel?.close()
        focus.startFocus()
    }

    /// 计时中菜单栏显示进度圆环，没在计时就是平时的星星
    private func updateStatusIcon() {
        guard let button = statusItem?.button else { return }
        if focus.timer.isActive {
            button.image = FocusStatusIcon.image(for: focus.timer, now: focus.now)
            button.toolTip = FocusStatusIcon.spokenText(for: focus.timer, now: focus.now)
        } else if button.image !== Self.brandIcon {
            button.image = Self.brandIcon
            button.toolTip = Self.brandToolTip
        }
    }

    private func showWelcome() {
        settings.welcomeShown = true
        welcome.show(WelcomeView(
            onOpenPanel: { [weak self] in
                self?.welcome.close()
                self?.showPanel()
            },
            onDismiss: { [weak self] in self?.welcome.close() }
        ))
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

    private func performOpen(_ app: RunningApp) {
        panel?.close()
        cleanup.open(app)
    }

    private func performBringBack(_ app: RunningApp) {
        panel?.close()
        cleanup.bringBack(app)
    }

    @objc private func togglePanel() {
        guard let panel else { return }
        if panel.isShown {
            panel.close()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel, !panel.isShown else { return }
        runningApps.refresh()
        usage.noteSeen(runningApps.apps)
        panel.show(near: statusItem?.button)
    }

    /// 已经在运行时，用户又在"应用程序"、启动台或聚焦搜索里打开 DeskTidy：多半是找不到菜单栏图标了
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showPanel()
        return false
    }
}
