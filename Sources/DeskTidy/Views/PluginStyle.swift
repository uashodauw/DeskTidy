import SwiftUI
import DeskTidyCore

/// 插件打开后的整块界面：底色是浅色或深色那一套，文字、按钮、开关跟着底色变。
struct PluginStyle: ViewModifier {
    @ObservedObject var settings: SettingsModel
    @Environment(\.colorScheme) private var systemScheme
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        let color = TitleColor.resolved(
            mode: settings.titleColorMode,
            isDarkAppearance: systemScheme == .dark,
            customLight: settings.titleColorLight,
            customDark: settings.titleColorDark
        )
        content
            .environment(\.systemIsDark, systemScheme == .dark)
            .environment(\.colorScheme, color.isDarkBackground ? .dark : .light)
            .tidyWindowGlass(cornerRadius: cornerRadius, tint: color.swiftUI)
    }
}

private struct SystemIsDarkKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 系统现在是不是深色。界面自己的深浅（跟着底色走）不要拿这个来判断。
    var systemIsDark: Bool {
        get { self[SystemIsDarkKey.self] }
        set { self[SystemIsDarkKey.self] = newValue }
    }
}

extension TitleColor {
    /// macOS 13 就有的写法。带色彩空间的 Color(.sRGB, …) 要 macOS 14，这里不能用。
    var swiftUI: Color {
        Color(red: red, green: green, blue: blue, opacity: 1)
    }
}
