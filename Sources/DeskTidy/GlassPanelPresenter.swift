import AppKit
import SwiftUI

/// 菜单栏图标下面的玻璃面板。
/// 不用系统的 NSPopover：它的背景是系统画的不透明底色，改不成半透明玻璃。
final class GlassPanelPresenter: NSObject {
    private let panel: KeyablePanel
    private var anchor: NSRect = .zero
    private var clickOutsideMonitor: Any?
    private var observers: [NSObjectProtocol] = []

    init<Content: View>(rootView: Content) {
        panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.onCancel = { [weak self] in self?.close() }
        panel.contentView = NSHostingView(rootView: rootView)

        // 内容变高变矮（展开/收起列表）时，窗口默认往上长；这里把顶边钉回菜单栏下面
        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.reposition() })
        // 用户切到别的应用（比如 Command + Tab）时收起，和系统弹出框的习惯一致
        observers.append(NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.close() })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
        removeClickOutsideMonitor()
    }

    var isShown: Bool { panel.isVisible }

    func show(below button: NSStatusBarButton) {
        guard let buttonWindow = button.window else { return }
        anchor = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        if let contentView = panel.contentView {
            panel.setContentSize(contentView.fittingSize)
        }
        reposition()
        // 不激活本应用：用户正在用的应用保持在前台，面板照样能接收键盘输入（录快捷键）
        panel.makeKeyAndOrderFront(nil)
        installClickOutsideMonitor()
    }

    func close() {
        guard panel.isVisible else { return }
        panel.orderOut(nil)
        removeClickOutsideMonitor()
    }

    private func reposition() {
        let size = panel.frame.size
        let screen = NSScreen.screens.first { $0.frame.intersects(anchor) } ?? NSScreen.main
        var x = anchor.midX - size.width / 2
        if let visible = screen?.visibleFrame {
            x = min(max(x, visible.minX + 8), visible.maxX - size.width - 8)
        }
        let origin = NSPoint(x: x, y: anchor.minY - 6 - size.height)
        if panel.frame.origin != origin {
            panel.setFrameOrigin(origin)
        }
    }

    /// 点到其他应用的任何地方就收起。点本应用自己的菜单栏图标不会触发这里，交给图标自己切换。
    private func installClickOutsideMonitor() {
        removeClickOutsideMonitor()
        clickOutsideMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.close()
        }
    }

    private func removeClickOutsideMonitor() {
        if let clickOutsideMonitor {
            NSEvent.removeMonitor(clickOutsideMonitor)
        }
        clickOutsideMonitor = nil
    }
}

/// 无边框窗口默认不能接收键盘输入，录快捷键、按 Esc 都需要它。
private final class KeyablePanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
