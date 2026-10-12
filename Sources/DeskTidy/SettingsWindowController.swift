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
    /// 最高的一页（6 个场景）也放得下
    private static let maxGlassHeight: CGFloat = 620

    private let scenes: SceneModel
    private let settings: SettingsModel
    private var window: SettingsWindow?

    init(scenes: SceneModel, settings: SettingsModel) {
        self.scenes = scenes
        self.settings = settings
    }

    func show() {
        let isNew = window == nil
        let window = self.window ?? makeWindow()
        self.window = window
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
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.15
            window.animator().alphaValue = 0
        }, completionHandler: {
            window.orderOut(nil)
            // 本应用没有别的窗口了，把前台还给用户原来的应用
            if NSApp.isActive {
                NSApp.deactivate()
            }
        })
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
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // 切到别的桌面时打开设置，窗口跟到当前桌面，不会把用户拽回原来的桌面
        window.collectionBehavior = [.moveToActiveSpace]
        window.onClose = { [weak self] in self?.close() }

        let root = SettingsRootView(scenes: scenes, settings: settings) { [weak self] in self?.close() }
            .background { SettingsShadow(cornerRadius: Self.cornerRadius) }
            .padding(Self.shadowMargin)
            .frame(width: Self.windowSize.width, height: Self.windowSize.height, alignment: .top)
        let host = NSHostingView(rootView: root)
        host.sizingOptions = []
        window.contentView = host
        return window
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

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        onClose?()
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
