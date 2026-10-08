import AppKit
import SwiftUI

/// 面板里的灰色按钮：平时浅灰，按下或选中时深灰。颜色切换不带动画，按下立刻有反应。
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
    private static var darkGray: Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDarkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(white: isDarkMode ? 0.45 : 0.28, alpha: 1)
        })
    }

    var body: some View {
        label
            .font(isLarge ? .body.weight(.semibold) : .callout)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isLarge ? 7 : 4)
            .padding(.horizontal, 6)
            .foregroundStyle(isDark ? Color.white : Color.primary)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isDark ? Self.darkGray : Color.primary.opacity(0.08))
            )
            .contentShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .transaction { $0.animation = nil }
    }
}
