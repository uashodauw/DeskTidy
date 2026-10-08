import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// 一键清理。默认 ⌥⌘K；用户改过之后，库会自己记住新快捷键。
    static let cleanDesktop = Self(
        "cleanDesktop",
        default: .init(.k, modifiers: [.option, .command])
    )
}
