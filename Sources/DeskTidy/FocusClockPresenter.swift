import AppKit
import SwiftUI

/// 屏幕角落的番茄钟小时钟窗口。
///
/// 窗口固定大小、背景透明，小时钟贴在右下角：变大、变小都发生在窗口里面，SwiftUI 动画才顺滑
/// （和面板同一个做法）。透明的部分点击会直接穿过去，不挡后面的东西。
/// 不抢键盘：点上面的按钮，用户正在打字的应用照样能继续打字。
final class FocusClockPresenter {
    /// 小时钟最大时（到点提醒）需要的空间
    static let contentSize = NSSize(width: 290, height: 210)
    static let shadowMargin: CGFloat = 56
    static let shadowTopMargin: CGFloat = 20
    private static let screenInset: CGFloat = 16
    private static let originKey = "focusClockOrigin"

    private let panel: KeyablePanel
    private var moveObserver: NSObjectProtocol?
    private var screenObserver: NSObjectProtocol?
    private(set) var isShown = false
    private var generation = 0

    init<Content: View>(rootView: Content) {
        panel = KeyablePanel(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.isMovableByWindowBackground = true
        // 只有输入框这类需要键盘的东西才让它接收键盘；按钮点了也不抢走用户的键盘
        panel.becomesKeyOnlyIfNeeded = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        // 切换桌面、别的应用全屏时，小时钟跟着出现在当前桌面
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.isReleasedWhenClosed = false

        let host = NSHostingView(rootView: ClockContainer { rootView })
        host.sizingOptions = []
        panel.contentView = host

        moveObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didMoveNotification, object: panel, queue: .main
        ) { [weak self] _ in self?.saveOrigin() }
        // 小时钟所在的显示器被拔掉、或分辨率变了：看不见了就挪回主屏幕右下角
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.keepOnScreen() }
    }

    deinit {
        for observer in [moveObserver, screenObserver].compactMap({ $0 }) {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    private func keepOnScreen() {
        guard isShown, !Self.isVisible(origin: panel.frame.origin) else { return }
        panel.setFrameOrigin(defaultOrigin())
    }

    private static var windowSize: NSSize {
        NSSize(
            width: contentSize.width + shadowMargin * 2,
            height: contentSize.height + shadowMargin + shadowTopMargin
        )
    }

    func show() {
        guard !isShown else { return }
        generation += 1
        isShown = true
        panel.setFrameOrigin(savedOrigin() ?? defaultOrigin())
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            panel.animator().alphaValue = 1
        }
    }

    func hide() {
        guard isShown else { return }
        generation += 1
        let current = generation
        isShown = false
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.generation == current else { return }
            self.panel.orderOut(nil)
        })
    }

    /// 默认在主屏幕右下角，程序坞上面
    private func defaultOrigin() -> NSPoint {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        return NSPoint(
            x: visible.maxX - Self.windowSize.width + Self.shadowMargin - Self.screenInset,
            y: visible.minY - Self.shadowMargin + Self.screenInset
        )
    }

    private func saveOrigin() {
        guard isShown else { return }
        let origin = panel.frame.origin
        UserDefaults.standard.set([Double(origin.x), Double(origin.y)], forKey: Self.originKey)
    }

    /// 上次拖到的位置。显示器拔掉了、分辨率变了导致那里已经看不到小时钟，就回到默认位置。
    private func savedOrigin() -> NSPoint? {
        guard let values = UserDefaults.standard.array(forKey: Self.originKey) as? [Double], values.count == 2 else {
            return nil
        }
        let origin = NSPoint(x: values[0], y: values[1])
        return Self.isVisible(origin: origin) ? origin : nil
    }

    /// 小时钟贴在窗口右下角；看那一块还在不在某块屏幕上
    private static func isVisible(origin: NSPoint) -> Bool {
        let clockArea = NSRect(
            x: origin.x + windowSize.width - shadowMargin - 120,
            y: origin.y + shadowMargin,
            width: 120,
            height: 50
        )
        return NSScreen.screens.contains { $0.visibleFrame.intersects(clockArea) }
    }

    private struct ClockContainer<Content: View>: View {
        @ViewBuilder let content: Content

        var body: some View {
            content
                .frame(
                    width: FocusClockPresenter.contentSize.width,
                    height: FocusClockPresenter.contentSize.height,
                    alignment: .bottomTrailing
                )
                .padding(.horizontal, FocusClockPresenter.shadowMargin)
                .padding(.bottom, FocusClockPresenter.shadowMargin)
                .padding(.top, FocusClockPresenter.shadowTopMargin)
        }
    }
}
