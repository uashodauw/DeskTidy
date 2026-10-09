import AppKit
import SwiftUI
import DeskTidyCore

/// 屏幕右上角的"这些应用很久没用了"小窗口。点它不会抢走用户正在用的应用的焦点。
final class IdleAppsPresenter {
    private static let cornerRadius: CGFloat = 18
    /// 窗口比玻璃大一圈，留给阴影；透明的部分点击会直接穿过去
    private static let shadowMargin: CGFloat = 56
    private static let shadowTopMargin: CGFloat = 20
    private static let screenInset: CGFloat = 16

    private var panel: NSPanel?

    func show(_ view: IdleAppsView) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let content = NSHostingView(rootView: ShadowedContainer { view })
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        if let screen = NSScreen.main?.visibleFrame {
            let size = panel.frame.size
            panel.setFrameOrigin(NSPoint(
                x: screen.maxX - size.width + Self.shadowMargin - Self.screenInset,
                y: screen.maxY - size.height + Self.shadowTopMargin - Self.screenInset
            ))
        }
        panel.orderFrontRegardless()
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
        // 系统阴影按整个窗口矩形画，四个角会露出一圈直角的灰边；阴影改由 SwiftUI 沿玻璃圆角画
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces]
        panel.isReleasedWhenClosed = false
        return panel
    }

    private struct ShadowedContainer<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            content
                .background { PanelShadow(cornerRadius: IdleAppsPresenter.cornerRadius) }
                .padding(.horizontal, IdleAppsPresenter.shadowMargin)
                .padding(.bottom, IdleAppsPresenter.shadowMargin)
                .padding(.top, IdleAppsPresenter.shadowTopMargin)
        }
    }
}
