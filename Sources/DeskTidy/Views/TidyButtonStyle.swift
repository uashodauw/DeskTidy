import AppKit
import SwiftUI

/// 面板里的玻璃按钮：平时是透明玻璃，按下或选中时变成深灰色玻璃。
struct TidyButtonStyle: ButtonStyle {
    var isSelected = false
    var isLarge = false

    func makeBody(configuration: Configuration) -> some View {
        TidyButtonBody(
            label: configuration.label,
            isDark: isSelected || configuration.isPressed,
            isLarge: isLarge
        )
    }
}

private struct TidyButtonBody<Label: View>: View {
    let label: Label
    let isDark: Bool
    let isLarge: Bool

    @Environment(\.isEnabled) private var isEnabled

    /// 深色模式下面板背景本身就很暗，深灰要稍微亮一点才看得出来。
    /// 不透明度要够高：玻璃后面的内容透上来时，白字仍然要看得清。
    private static var darkGray: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(white: isDarkMode ? 0.45 : 0.25, alpha: 0.85)
        })
    }

    var body: some View {
        label
            .font(isLarge ? .body.weight(.semibold) : .callout)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isLarge ? 8 : 5)
            .padding(.horizontal, 6)
            .foregroundStyle(isDark ? Color.white : Color.primary)
            .contentShape(Capsule())
            .tidyGlass(in: Capsule(), tint: isDark ? Self.darkGray : nil, interactive: isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
            .transaction { $0.animation = nil }
    }
}
