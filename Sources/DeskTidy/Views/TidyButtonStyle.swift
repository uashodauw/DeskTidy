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
            isPressed: configuration.isPressed,
            isLarge: isLarge
        )
    }
}

enum TidyMotion {
    /// 按下：快速缩一点；松手：带一点回弹地弹回去，和 iOS 按钮的手感一致
    static let press = Animation.spring(response: 0.22, dampingFraction: 0.62)
    /// 颜色变化：很短的渐变，比硬切顺眼，又不会让人觉得慢
    static let color = Animation.easeOut(duration: 0.14)
    /// 展开/收起、切换场景
    static let layout = Animation.spring(response: 0.34, dampingFraction: 0.86)
}

private struct TidyButtonBody<Label: View>: View {
    let label: Label
    let isDark: Bool
    let isPressed: Bool
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
            .font(.body)
            .lineLimit(1)
            .frame(maxWidth: .infinity)
            .padding(.vertical, isLarge ? 8 : 5)
            .padding(.horizontal, 6)
            .foregroundStyle(isDark ? Color.white : Color.primary)
            .contentShape(Capsule())
            .tidyGlass(in: Capsule(), tint: isDark ? Self.darkGray : nil, interactive: isEnabled)
            .opacity(isEnabled ? 1 : 0.45)
            .animation(TidyMotion.color, value: isDark)
            .scaleEffect(isPressed ? 0.96 : 1)
            .animation(TidyMotion.press, value: isPressed)
    }
}
