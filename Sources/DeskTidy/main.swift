import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 只在菜单栏显示，不在 Dock 里出现图标
app.setActivationPolicy(.accessory)
app.run()
