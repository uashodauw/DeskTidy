import AppKit
import SwiftUI
import DeskTidyCore

/// 休息时盖住每一块屏幕的玻璃窗口。
/// 只盖一层，不碰任何应用：跳过或休息结束，玻璃退去，一切都在原地。
final class BreakOverlayPresenter {
    private let focus: FocusModel
    private var panels: [KeyablePanel] = []
    private var screenObserver: NSObjectProtocol?
    private(set) var isShown = false
    private var generation = 0

    private var tip = ""
    private var skipAvailableAt = Date()
    /// 用户点了跳过（或按了 esc）
    var onSkip: (() -> Void)?

    init(focus: FocusModel) {
        self.focus = focus
        // 接上、拔掉显示器或改分辨率时，重新按现在的屏幕铺一遍
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.rebuildIfShown() }
    }

    deinit {
        if let screenObserver {
            NotificationCenter.default.removeObserver(screenObserver)
        }
    }

    func show(tip: String, skipDelay: TimeInterval) {
        guard !isShown else { return }
        generation += 1
        isShown = true
        self.tip = tip
        skipAvailableAt = Date().addingTimeInterval(skipDelay)
        buildPanels(fadeIn: true)
    }

    func hide() {
        guard isShown else { return }
        generation += 1
        let current = generation
        isShown = false
        let closing = panels
        panels = []
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.45
            context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            closing.forEach { $0.animator().alphaValue = 0 }
        }, completionHandler: { [weak self] in
            closing.forEach { $0.orderOut(nil) }
            guard let self, self.generation == current else { return }
            // 把键盘还给用户原来的应用
            if NSApp.isActive {
                NSApp.deactivate()
            }
        })
    }

    private func rebuildIfShown() {
        guard isShown else { return }
        panels.forEach { $0.orderOut(nil) }
        panels = []
        buildPanels(fadeIn: false)
    }

    private func buildPanels(fadeIn: Bool) {
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        for screen in NSScreen.screens {
            let panel = makePanel(for: screen, showsClock: screen == mainScreen)
            panel.alphaValue = fadeIn ? 0 : 1
            if screen == mainScreen {
                // 主屏幕的玻璃接收键盘，按 esc 才能跳过；不激活本应用
                panel.makeKeyAndOrderFront(nil)
            } else {
                panel.orderFrontRegardless()
            }
            panels.append(panel)
        }
        guard fadeIn else { return }
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.6
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panels.forEach { $0.animator().alphaValue = 1 }
        }
    }

    private func makePanel(for screen: NSScreen, showsClock: Bool) -> KeyablePanel {
        let panel = KeyablePanel(
            contentRect: screen.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        // 盖过菜单栏和程序坞，也盖过别的应用的全屏窗口
        panel.level = .screenSaver
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.onCancel = { [weak self] in self?.skipIfAllowed() }
        panel.contentView = NSHostingView(rootView: BreakOverlayView(
            focus: focus,
            showsClock: showsClock,
            tip: tip,
            skipAvailableAt: skipAvailableAt,
            onSkip: { [weak self] in self?.skipIfAllowed() }
        ))
        panel.setFrame(screen.frame, display: false)
        return panel
    }

    private func skipIfAllowed() {
        guard isShown, Date() >= skipAvailableAt else { return }
        onSkip?()
    }
}

/// 用户是不是正在用全屏应用（看视频、做演示）：这时不铺满屏幕，免得突然挡住。
/// 只看窗口大小，不需要"屏幕录制"权限。
enum FullScreenDetector {
    static func frontmostAppIsFullScreen() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]] else { return false }
        let screenSizes = NSScreen.screens.map(\.frame.size)
        return windows.contains { info in
            guard (info[kCGWindowOwnerPID as String] as? Int32) == app.processIdentifier,
                  (info[kCGWindowLayer as String] as? Int) == 0,
                  let boundsInfo = info[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsInfo as CFDictionary) else { return false }
            return screenSizes.contains { abs($0.width - bounds.width) < 1 && abs($0.height - bounds.height) < 1 }
        }
    }
}
