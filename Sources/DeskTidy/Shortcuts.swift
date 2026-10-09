import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// 一键清理。默认 ⌥⌘K；用户改过之后，库会自己记住新快捷键。
    static let cleanDesktop = Self(
        "cleanDesktop",
        default: .init(.k, modifiers: [.option, .command])
    )

    /// 打开或收起面板，菜单栏图标被挤掉时也能用。默认 ⌥⌘J（挨着清理的 K；⌥⌘D 被系统用来显示/隐藏程序坞）。
    static let togglePanel = Self(
        "togglePanel",
        default: .init(.j, modifiers: [.option, .command])
    )
}
