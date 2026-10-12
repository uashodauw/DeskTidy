import AppKit
import SwiftUI

/// macOS 标准的设置窗口：顶部一排图标标签（场景、清理、专注、快捷键），和系统自带应用的"设置"一样。
/// 窗口刚好装下当前标签页的内容，切换标签时平滑地变高变矮，不能手动拉大拉小。
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let scenes: SceneModel
    private let settings: SettingsModel
    private var window: NSWindow?

    init(scenes: SceneModel, settings: SettingsModel) {
        self.scenes = scenes
        self.settings = settings
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        // DeskTidy 平时不在前台；设置窗口要能打字（改场景名字），得先把本应用调到前台
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// 关掉后本应用没有别的窗口了，把前台还给用户原来的应用
    func windowWillClose(_ notification: Notification) {
        DispatchQueue.main.async {
            if NSApp.isActive {
                NSApp.deactivate()
            }
        }
    }

    private func makeWindow() -> NSWindow {
        let tabs = SettingsTabViewController()
        tabs.tabStyle = .toolbar
        tabs.addTabViewItem(Self.tab("场景", symbol: "square.stack.3d.up", SceneSettingsPage(scenes: scenes)))
        tabs.addTabViewItem(Self.tab("清理", symbol: "wand.and.stars", CleanSettingsPage(settings: settings)))
        tabs.addTabViewItem(Self.tab("专注", symbol: "timer", FocusSettingsPage(settings: settings)))
        tabs.addTabViewItem(Self.tab("快捷键", symbol: "keyboard", ShortcutSettingsPage()))

        let window = SettingsWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.isReleasedWhenClosed = false
        window.delegate = self
        // 切到别的桌面时打开设置，窗口跟到当前桌面，不会把用户拽回原来的桌面
        window.collectionBehavior = [.moveToActiveSpace]
        tabs.fitWindowToSelectedTab(animated: false)
        window.center()
        return window
    }

    private static func tab<Content: View>(_ title: String, symbol: String, _ page: Content) -> NSTabViewItem {
        let host = NSHostingController(rootView: page)
        // 内容变高变矮时（比如关掉提示音、多了一个场景）告诉窗口跟着调整
        host.sizingOptions = [.preferredContentSize]
        let item = NSTabViewItem(viewController: host)
        item.label = title
        item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: title)
        return item
    }
}

/// 切换标签、内容变化时，让窗口刚好包住当前页，顶边不动、往下伸缩
private final class SettingsTabViewController: NSTabViewController {
    override func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) {
        super.tabView(tabView, didSelect: tabViewItem)
        fitWindowToSelectedTab(animated: true)
    }

    override func preferredContentSizeDidChange(for viewController: NSViewController) {
        super.preferredContentSizeDidChange(for: viewController)
        guard viewController == tabViewItems[safe: selectedTabViewItemIndex]?.viewController else { return }
        fitWindowToSelectedTab(animated: true)
    }

    func fitWindowToSelectedTab(animated: Bool) {
        guard let window = view.window,
              let page = tabViewItems[safe: selectedTabViewItemIndex]?.viewController else { return }
        let size = page.view.fittingSize
        guard size.width > 0, size.height > 0 else { return }
        var frame = window.frameRect(forContentRect: NSRect(origin: .zero, size: size))
        frame.origin = NSPoint(x: window.frame.minX, y: window.frame.maxY - frame.height)
        window.setFrame(frame, display: true, animate: animated && window.isVisible)
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

/// DeskTidy 没有菜单栏菜单，系统就不知道 ⌘C、⌘V 这些快捷键该做什么；在设置窗口里自己接住它们
private final class SettingsWindow: NSWindow {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask) == .command,
              let key = event.charactersIgnoringModifiers?.lowercased() else {
            return super.performKeyEquivalent(with: event)
        }
        if key == "w" {
            performClose(nil)
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
