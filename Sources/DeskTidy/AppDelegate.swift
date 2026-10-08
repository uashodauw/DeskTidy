import AppKit
import SwiftUI
import DeskTidyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        let host = NSHostingController(rootView: PanelView())
        popover.contentViewController = host
        popover.contentSize = host.view.fittingSize
        popover.behavior = .transient

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "sparkles", accessibilityDescription: AppInfo.displayName)
            button.title = " 清理"
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(togglePanel)
        }
        statusItem = item

        print("\(AppInfo.displayName) \(AppInfo.version) 已启动，请看屏幕右上角菜单栏里写着「清理」的图标。")
    }

    @objc private func togglePanel() {
        guard let button = statusItem?.button else { return }
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
