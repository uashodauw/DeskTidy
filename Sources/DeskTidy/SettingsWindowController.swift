import AppKit
import SwiftUI

/// 设置窗口：和面板同一种液态玻璃，透出后面的桌面。顶部一排玻璃标签（场景、清理、专注、快捷键）。
///
/// 窗口固定大小、背景全透明，玻璃贴在上面一部分（和面板同一个做法）：
/// 切换标签时玻璃在窗口里面平滑地变高变矮；如果让窗口跟着改大小，只能一下子跳过去。
/// 透明部分的点击会直接穿过去。
final class SettingsWindowController: NSObject {
    static let cornerRadius: CGFloat = 22
    /// 窗口四周留给阴影的空间，要比阴影扩散的范围大，否则阴影会被窗口边缘切出硬边
    static let shadowMargin: CGFloat = 72
    /// 最高的一页（外观圆盘，或 6 个场景）也放得下
    private static let maxGlassHeight: CGFloat = 780

    private let scenes: SceneModel
    private let settings: SettingsModel
    private var window: SettingsWindow?
    /// 关掉的淡出还没结束又打开时，旧的淡出不能把新打开的窗口移出屏幕
    private var closeGeneration = 0

    init(scenes: SceneModel, settings: SettingsModel) {
        self.scenes = scenes
        self.settings = settings
    }

    func show() {
        closeGeneration += 1
        let isNew = window == nil
        let window = self.window ?? makeWindow()
        self.window = window
        // 关掉时为了退出调度中心标过 transient，再打开要回到「跟着当前桌面」
        window.collectionBehavior = [.moveToActiveSpace]
        window.ignoresMouseEvents = false
        if isNew || !window.isVisible {
            window.setFrameOrigin(origin(for: window.frame.size))
        }
        // DeskTidy 平时不在前台；设置窗口要能打字（改场景名字），得先把本应用调到前台
        NSApp.activate(ignoringOtherApps: true)
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        // 不让系统自动把光标放进场景名字框里
        window.makeFirstResponder(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.22
            window.animator().alphaValue = 1
        }
    }

    func close() {
        guard let window, window.isVisible else { return }
        closeGeneration += 1
        let generation = closeGeneration
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            // 完成回调跑的时候，这次淡出的动画还没提交完。
            // 立刻 orderOut 会被盖掉，窗口以全透明留在屏幕上。等提交完再拿掉。
            DispatchQueue.main.async {
                guard let self, self.closeGeneration == generation else { return }
                self.orderOutOfMissionControl()
            }
        })
    }

    /// 把设置窗口从屏幕上拿掉，并让「调度中心」（三指上滑）忘掉它。
    ///
    /// 菜单栏面板、提示和小时钟一开始就不参加调度中心。设置窗口要跟着当前桌面走，
    /// 所以会参加。淡出把透明度收到 0 之后如果窗口还留在窗口列表里，桌面上看不见，
    /// 三指上滑里却有一块全透明的窗口。macOS 26 还有一个系统问题：普通窗口就算已经
    /// orderOut，调度中心也不把它注销。先标成 transient，调度中心就不再管它；
    /// 透明度停在 0 的话窗口服务器仍会留下这块透明窗口，所以拿掉之后把透明度设回 1。
    private func orderOutOfMissionControl() {
        guard let window else { return }
        window.collectionBehavior.insert(.transient)
        // 万一窗口仍被留在屏幕上（全透明），点击要穿过去，不能挡住后面的应用
        window.ignoresMouseEvents = true
        window.orderOut(nil)
        // 分组里把透明度设回去，避免这一下自己再做一次动画，把窗口重新显示出来
        NSAnimationContext.beginGrouping()
        NSAnimationContext.current.duration = 0
        NSAnimationContext.current.allowsImplicitAnimation = false
        if !window.isVisible {
            window.alphaValue = 1
        }
        NSAnimationContext.endGrouping()
        // 本应用没有别的窗口了，把前台还给用户原来的应用
        if NSApp.isActive {
            NSApp.deactivate()
        }
    }

    private static var windowSize: NSSize {
        NSSize(
            width: settingsPageWidth + shadowMargin * 2,
            height: maxGlassHeight + shadowMargin * 2
        )
    }

    /// 玻璃的顶边放在屏幕上方大约五分之一处，左右居中
    private func origin(for size: NSSize) -> NSPoint {
        let visible = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
        let glassTop = visible.maxY - visible.height * 0.18
        return NSPoint(
            x: visible.midX - size.width / 2,
            y: glassTop + Self.shadowMargin - size.height
        )
    }

    private func makeWindow() -> SettingsWindow {
        let window = SettingsWindow(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        // 系统阴影按整个窗口矩形画，四个角会露出直角；阴影改由 SwiftUI 沿玻璃圆角画
        window.hasShadow = false
        // 不能开「按住空白处拖动窗口」：系统会把圆盘上的拖动也当成拖窗口，圆盘就收不到移动。
        // 要挪窗口，按住顶部「设置」那一行。
        window.isMovableByWindowBackground = false
        window.isReleasedWhenClosed = false
        // 出现和消失由自己做淡入淡出。系统自带的窗口动画会和这次淡出抢，
        // 把已经移走的窗口又留在屏幕上。
        window.animationBehavior = .none
        // 切到别的桌面时打开设置，窗口跟到当前桌面，不会把用户拽回原来的桌面。
        // 不能在这里标成 transient：打开时它是普通窗口。关掉时再标，见 orderOutOfMissionControl。
        window.collectionBehavior = [.moveToActiveSpace]
        window.onClose = { [weak self] in self?.close() }

        let root = SettingsRootView(scenes: scenes, settings: settings) { [weak self] in self?.close() }
            .background { SettingsShadow(cornerRadius: Self.cornerRadius) }
            .padding(Self.shadowMargin)
            .frame(width: Self.windowSize.width, height: Self.windowSize.height, alignment: .top)
        let host = SettingsHostingView(rootView: root)
        host.sizingOptions = []
        window.contentView = host
        return window
    }
}

/// 设置窗口里的点击都不能拿去拖窗口。拖窗口只发生在顶部标题那一行，由那里的手势主动开始。
final class SettingsHostingView<Content: View>: NSHostingView<Content> {
    override var mouseDownCanMoveWindow: Bool { false }

    override func mouseDown(with event: NSEvent) {
        (window as? SettingsWindow)?.rememberMouseDown(event)
        super.mouseDown(with: event)
    }
}

/// 按住顶部「设置」时，用刚才那下按下把窗口拖走。
enum SettingsWindowDrag {
    static var gesture: some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { _ in
                (NSApp.keyWindow as? SettingsWindow)?.beginManualDrag()
            }
    }
}

/// 设置窗口的阴影：三层叠加，和 iOS、macOS 浮起来的卡片一样——
/// 大而很淡的一层往下扩散，表现"浮在空中"；中间一层给出厚度；贴边一层很细，让边缘有轮廓但看不出一圈黑线。
/// 只画在玻璃外面（玻璃是透明的，里面有阴影会把玻璃弄脏）；拍平成一张图，拖动窗口时不会每帧重算。
struct SettingsShadow: View {
    let cornerRadius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
        let reach = SettingsWindowController.shadowMargin
        ZStack {
            shape.fill(Color.black).shadow(color: .black.opacity(0.16), radius: 36, y: 22)
            shape.fill(Color.black).shadow(color: .black.opacity(0.08), radius: 10, y: 5)
            shape.fill(Color.black).shadow(color: .black.opacity(0.10), radius: 1, y: 0.5)
        }
        .mask(OutsideOf(cornerRadius: cornerRadius).fill(style: FillStyle(eoFill: true)))
        .padding(reach)
        .drawingGroup()
        .padding(-reach)
    }
}

/// 无边框窗口默认不能接收键盘输入，改场景名字需要它。
/// DeskTidy 没有菜单栏菜单，系统就不知道 ⌘C、⌘V 这些快捷键该做什么，在这里自己接住；⌘W 和 esc 关闭窗口。
final class SettingsWindow: NSWindow {
    var onClose: (() -> Void)?
    private var lastMouseDown: NSEvent?
    private var isDraggingWindow = false

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
    }

    func rememberMouseDown(_ event: NSEvent) {
        guard !isDraggingWindow else { return }
        lastMouseDown = event
    }

    /// 用按下那一下把窗口拖走。圆盘不走这里。
    func beginManualDrag() {
        guard !isDraggingWindow, let event = lastMouseDown else { return }
        isDraggingWindow = true
        lastMouseDown = nil
        performDrag(with: event)
        isDraggingWindow = false
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        if key == "w" {
            onClose?()
            return true
        }
        let actions: [String: Selector] = [
            "x": #selector(NSText.cut(_:)),
            "c": #selector(NSText.copy(_:)),
            "v": #selector(NSText.paste(_:)),
            "a": #selector(NSText.selectAll(_:)),
            "z": Selector(("undo:")),
        ]
        if let action = actions[key], NSApp.sendAction(action, to: nil, from: self) {
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}
