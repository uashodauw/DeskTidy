import AppKit
import SwiftUI
import DeskTidyCore

/// 屏幕右上角的"这些应用很久没用了"小窗口。点它不会抢走用户正在用的应用的焦点。
final class IdleAppsPresenter {
    private var panel: NSPanel?

    func show(_ view: IdleAppsView) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let content = NSHostingView(rootView: view)
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        if let screen = NSScreen.main?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(x: screen.maxX - size.width - 16, y: screen.maxY - size.height - 16))
        }
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.title = "这些应用很久没用了"
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.isReleasedWhenClosed = false
        return panel
    }
}
