import AppKit
import QuartzCore
import SwiftUI

/// 菜单栏图标下面的玻璃面板。
/// 不用系统的 NSPopover：它的背景是系统画的不透明底色，改不成半透明玻璃。
///
/// 窗口固定高度、背景全透明，面板只占上面一部分：
/// 展开/收起列表时，变化发生在窗口里面，才能用 SwiftUI 动画平滑地伸缩；
/// 如果让窗口跟着内容改大小，窗口只能一下子跳到新尺寸，看起来一卡一卡的。
/// 透明部分的点击会直接穿过去，不会挡住后面的窗口。
final class GlassPanelPresenter: NSObject {
    static let panelWidth: CGFloat = 260
    static let cornerRadius: CGFloat = 18
    /// 面板左右和下方留给阴影的空间。必须比阴影扩散的范围大，否则阴影会被窗口边缘切出一条硬直线。
    static let shadowMargin: CGFloat = 56
    /// 面板上方留给阴影的空间（阴影主要往下落，上面用不了那么多）
    static let shadowTopMargin: CGFloat = 20

    private let panel: KeyablePanel
    private var clickOutsideMonitor: Any?
    private var activationObserver: NSObjectProtocol?
    private(set) var isShown = false
    /// 快速连续开关时，旧的收起动画结束后不能把新打开的面板也收掉
    private var generation = 0

    private let maxHeight: CGFloat = 760
    private let dropDistance: CGFloat = 8

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
        // 阴影由 SwiftUI 画：窗口自带的阴影按整个窗口算，面板伸缩时不会跟着变
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle]
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.onCancel = { [weak self] in self?.close() }

        let host = NSHostingView(rootView: PanelContainer { rootView })
        // 窗口大小由这里决定，不跟着内容变
        host.sizingOptions = []
        panel.contentView = host

        // 用户切到别的应用（比如 Command + Tab）时收起，和系统弹出框的习惯一致。
        // 本应用自己被激活（用户在"应用程序"里再次打开 DeskTidy）时不收起：那正是要打开面板
        let ownProcessID = ProcessInfo.processInfo.processIdentifier
        activationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { [weak self] note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.processIdentifier != ownProcessID else { return }
            self?.close()
        }
    }

    deinit {
        if let activationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(activationObserver)
        }
        removeClickOutsideMonitor()
    }

    /// 像 iOS 一样从菜单栏轻轻落下并淡入，最后带一点点回弹。
    /// 动画做在整个窗口上而不是 SwiftUI 里：老系统的毛玻璃是系统直接画的，SwiftUI 的缩放和透明度管不到它。
    /// 菜单栏图标看得见就落在图标下面；图标被挤掉了（菜单栏太满、藏在刘海后面）就落在屏幕右上角。
    func show(near button: NSStatusBarButton?) {
        if let button, let anchor = Self.visibleAnchor(of: button) {
            present(below: anchor)
        } else {
            let screen = NSScreen.main ?? NSScreen.screens.first
            let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
            let x = visible.maxX - Self.screenEdgeInset - Self.panelWidth / 2
            present(below: NSRect(x: x, y: visible.maxY, width: 1, height: 1))
        }
    }

    private static let screenEdgeInset: CGFloat = 16

    /// 系统藏起图标时不会告诉应用，只能看图标窗口还在不在屏幕上、有没有被刘海挡住
    private static func visibleAnchor(of button: NSStatusBarButton) -> NSRect? {
        guard let window = button.window, window.isVisible, window.occlusionState.contains(.visible) else { return nil }
        let anchor = window.convertToScreen(button.convert(button.bounds, to: nil))
        guard let screen = NSScreen.screens.first(where: { $0.frame.intersects(anchor) }) else { return nil }
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea,
           anchor.midX > left.maxX, anchor.midX < right.minX {
            return nil
        }
        return anchor
    }

    private func present(below anchor: NSRect) {
        generation += 1
        isShown = true
        let finalFrame = frame(below: anchor)

        panel.setFrame(finalFrame.offsetBy(dx: 0, dy: dropDistance), display: false)
        panel.alphaValue = 0
        // 不激活本应用：用户正在用的应用保持在前台，面板照样能接收键盘输入（录快捷键）
        panel.makeKeyAndOrderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.26
            context.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 1.15, 0.35, 1)
            panel.animator().setFrame(finalFrame, display: true)
            panel.animator().alphaValue = 1
        }
        installClickOutsideMonitor()
    }

    func close() {
        guard isShown else { return }
        generation += 1
        let current = generation
        isShown = false
        removeClickOutsideMonitor()
        // 从"应用程序"里打开面板时本应用被激活了；收起后把键盘焦点还给用户原来的应用
        if NSApp.isActive {
            NSApp.deactivate()
        }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.12
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            guard let self, self.generation == current else { return }
            self.panel.orderOut(nil)
        })
    }

    /// 面板顶边在菜单栏下面 6 点；窗口四周再留出阴影的位置。
    /// 窗口上沿会伸进菜单栏一点，那部分是透明的，点击会直接穿过去，不影响点菜单栏。
    private func frame(below anchor: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.frame.contains(NSPoint(x: anchor.midX, y: anchor.minY)) } ?? NSScreen.main
        let visible = screen?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let margin = Self.shadowMargin
        let width = Self.panelWidth + margin * 2
        let top = anchor.minY - 6 + Self.shadowTopMargin
        let height = min(maxHeight + Self.shadowTopMargin, top - visible.minY)
        var x = anchor.midX - width / 2
        x = min(max(x, visible.minX - margin + 8), visible.maxX - width + margin - 8)
        return NSRect(x: x, y: top - height, width: width, height: height)
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

/// 把面板放在透明窗口的顶部，并在面板外围画阴影。
private struct PanelContainer<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(width: GlassPanelPresenter.panelWidth)
            .background { PanelShadow(cornerRadius: GlassPanelPresenter.cornerRadius) }
            .padding(.horizontal, GlassPanelPresenter.shadowMargin)
            .padding(.top, GlassPanelPresenter.shadowTopMargin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

/// 只在面板边缘外面画阴影，不画在面板里面：玻璃是半透明的，里面有阴影会把整块玻璃弄脏。
struct PanelShadow: View {
    let cornerRadius: CGFloat

    /// 两层阴影叠加，和 iOS 浮层的做法一样：
    /// 大而淡的一层往下扩散，表现"浮在空中"；贴边很淡的一层，让边缘有轮廓但不会出现一圈黑线。
    /// 拍平成一张图再贴上去：模糊阴影加遮罩，系统不会缓存，
    /// 面板里一滚动整个窗口每帧都要重新合成，阴影也跟着每帧重算，快速滑动列表就会卡。
    /// 拍平的范围要包含面板外面的阴影，所以先往外扩，拍完再缩回来，不影响布局。
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
        let reach = GlassPanelPresenter.shadowMargin
        ZStack {
            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(0.12), radius: 20, y: 12)
            shape
                .fill(Color.black)
                .shadow(color: .black.opacity(0.07), radius: 3, y: 1)
        }
        .mask(OutsideOf(cornerRadius: cornerRadius).fill(style: FillStyle(eoFill: true)))
        .padding(reach)
        .drawingGroup()
        .padding(-reach)
    }
}

/// 面板外面的区域。挖掉的洞比面板大 1 点：洞和面板一样大时，抗锯齿会在边缘留下一道细黑线。
private struct OutsideOf: Shape {
    let cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        let reach = GlassPanelPresenter.shadowMargin * 2
        var path = Path(rect.insetBy(dx: -reach, dy: -reach))
        path.addRoundedRect(
            in: rect.insetBy(dx: -1, dy: -1),
            cornerSize: CGSize(width: cornerRadius + 1, height: cornerRadius + 1),
            style: .circular
        )
        return path
    }
}

/// 无边框窗口默认不能接收键盘输入，录快捷键、按 Esc 都需要它。
final class KeyablePanel: NSPanel {
    var onCancel: (() -> Void)?

    override var canBecomeKey: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }
}
