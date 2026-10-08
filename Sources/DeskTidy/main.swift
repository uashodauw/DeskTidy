import AppKit
import DeskTidyCore

// 必须在创建 AppDelegate 之前：场景、设置和快捷键在那时就会读取保存的数据
if Bundle.main.bundleIdentifier != nil {
    LegacySettingsMigration.migrate(
        legacy: UserDefaults.standard.persistentDomain(forName: LegacySettingsMigration.legacyDomain),
        into: .standard
    )
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
// 只在菜单栏显示，不在 Dock 里出现图标
app.setActivationPolicy(.accessory)
app.run()
