import AppKit
import SwiftUI
import DeskTidyCore

/// 屏幕中央的提示浮窗：淡入，停留一会儿，淡出。鼠标可以直接点穿它。
final class ToastPresenter {
    private let visibleDuration: TimeInterval = 1.5
    private var panel: NSPanel?
    /// 连续清理时，旧浮窗的淡出不能把新浮窗也收掉
    private var generation = 0

    func show(_ feedback: CleanupFeedback) {
        generation += 1
        let current = generation

        let panel = self.panel ?? makePanel()
        self.panel = panel
        let content = NSHostingView(rootView: ToastView(feedback: feedback))
        let size = content.fittingSize
        panel.contentView = content
        if let screen = NSScreen.main?.visibleFrame {
            panel.setFrame(
                NSRect(x: screen.midX - size.width / 2, y: screen.midY - size.height / 2, width: size.width, height: size.height),
                display: true
            )
        }

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.15
            panel.animator().alphaValue = 1
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + visibleDuration) { [weak self] in
            guard let self, self.generation == current else { return }
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.4
                panel.animator().alphaValue = 0
            }, completionHandler: { [weak self] in
                guard let self, self.generation == current else { return }
                panel.orderOut(nil)
            })
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.ignoresMouseEvents = true
        // 面板默认在本应用失去焦点时立刻隐藏，用户一点别的窗口浮窗就没了
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        return panel
    }
}
