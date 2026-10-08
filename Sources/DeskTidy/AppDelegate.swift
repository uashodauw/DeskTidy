import AppKit
import DeskTidyCore

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 只在菜单栏显示，不在 Dock 里出现图标
        NSApp.setActivationPolicy(.accessory)
        print("\(AppInfo.displayName) \(AppInfo.version) 已启动，请看屏幕右上角菜单栏的 ✨ 图标。")
    }
}
