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
        // 透明窗口的阴影按内容形状生成，内容换了要重新算
        panel.invalidateShadow()
    }

    func close() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        // 无边框：带标题栏的窗口被点中后，系统会画出自己的边框和标题栏底色，和玻璃圆角对不上
        let panel = KeyablePanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.onCancel = { [weak self] in self?.close() }
        panel.title = "这些应用很久没用了"
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.isReleasedWhenClosed = false
        return panel
    }
}
