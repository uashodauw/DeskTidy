import AppKit
import SwiftUI
import DeskTidyCore

/// 浮在其他窗口上面的玻璃小窗口（"这些应用很久没用了"、第一次打开的欢迎窗口）。
/// 点它不会抢走用户正在用的应用的焦点。
final class GlassWindowPresenter {
    enum Placement {
        case topRight
        case center
    }

    private static let cornerRadius: CGFloat = 18
    /// 窗口比玻璃大一圈，留给阴影；透明的部分点击会直接穿过去
    private static let shadowMargin: CGFloat = 56
    private static let shadowTopMargin: CGFloat = 20
    private static let screenInset: CGFloat = 16

    private let placement: Placement
    private var panel: NSPanel?

    init(placement: Placement) {
        self.placement = placement
    }

    func show<Content: View>(_ view: Content) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        let content = NSHostingView(rootView: ShadowedContainer { view })
        panel.contentView = content
        panel.setContentSize(content.fittingSize)
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrameOrigin(origin(for: panel.frame.size, in: screen))
        }
        panel.orderFrontRegardless()
    }

    func close() {
        panel?.orderOut(nil)
    }

    /// 位置按玻璃算，不按窗口算：窗口四周多出来的是透明的阴影区域
    private func origin(for size: NSSize, in screen: NSRect) -> NSPoint {
        switch placement {
        case .topRight:
            return NSPoint(
                x: screen.maxX - size.width + Self.shadowMargin - Self.screenInset,
                y: screen.maxY - size.height + Self.shadowTopMargin - Self.screenInset
            )
        case .center:
            let glassHeight = size.height - Self.shadowMargin - Self.shadowTopMargin
            let glassTop = screen.midY + glassHeight / 2 + screen.height * 0.08
            return NSPoint(
                x: screen.midX - size.width / 2,
                y: glassTop + Self.shadowTopMargin - size.height
            )
        }
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
                .background { PanelShadow(cornerRadius: GlassWindowPresenter.cornerRadius) }
                .padding(.horizontal, GlassWindowPresenter.shadowMargin)
                .padding(.bottom, GlassWindowPresenter.shadowMargin)
                .padding(.top, GlassWindowPresenter.shadowTopMargin)
        }
    }
}
