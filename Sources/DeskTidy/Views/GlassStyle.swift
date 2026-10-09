import AppKit
import SwiftUI

/// 统一的玻璃质感：macOS 26 及以上用系统的 Liquid Glass；更老的系统（或用旧版 Xcode 编译）退回毛玻璃。
/// `#if compiler(>=6.2)` 不能去掉：旧版 Xcode 不认识 glassEffect，直接写会编译失败。
extension View {
    @ViewBuilder
    func tidyGlass<S: Shape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            glassEffect(TidyGlass.make(tint: tint, interactive: interactive), in: shape)
        } else {
            frostedGlass(in: shape, tint: tint)
        }
        #else
        frostedGlass(in: shape, tint: tint)
        #endif
    }

    /// 整个窗口的玻璃背景（面板、提示浮窗、"很久没用"窗口）：透过它能看到后面的桌面和其他窗口。
    /// 窗口本身必须是透明的（isOpaque = false、backgroundColor = .clear），否则透不出去。
    @ViewBuilder
    func tidyWindowGlass(cornerRadius: CGFloat) -> some View {
        // 用普通圆角而不是 .continuous：要和退路方案里模糊层的圆角遮罩完全重合，边框才贴得住
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            behindWindowGlass(in: shape)
        }
        #else
        behindWindowGlass(in: shape)
        #endif
    }

    private func behindWindowGlass(in shape: RoundedRectangle) -> some View {
        background {
            BehindWindowBlur(cornerRadius: shape.cornerSize.width)
                .overlay(shape.strokeBorder(Self.glassEdge, lineWidth: 0.5))
        }
    }

    /// 玻璃边缘的高光：顶部亮、往下逐渐淡掉，像光从上面照下来。整圈一样亮会显得像一道生硬的边框。
    private static var glassEdge: LinearGradient {
        LinearGradient(
            colors: [Color.white.opacity(0.45), Color.white.opacity(0.12), Color.white.opacity(0.05)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func frostedGlass<S: Shape>(in shape: S, tint: Color?) -> some View {
        background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint {
                    shape.fill(tint)
                }
                shape.stroke(Self.glassEdge, lineWidth: 0.5)
            }
        }
    }
}

#if compiler(>=6.2)
@available(macOS 26.0, *)
private enum TidyGlass {
    static func make(tint: Color?, interactive: Bool) -> Glass {
        let tinted = tint.map { Glass.regular.tint($0) } ?? .regular
        return interactive ? tinted.interactive() : tinted
    }
}
#endif

/// 模糊窗口后面的桌面和其他应用（SwiftUI 自带的毛玻璃只模糊本窗口里的内容）。
/// 圆角必须用 maskImage 做：透窗模糊由系统直接合成，SwiftUI 的 clipShape 裁不到它，四个角会露出直角方块。
private struct BehindWindowBlur: NSViewRepresentable {
    let cornerRadius: CGFloat

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .menu
        view.blendingMode = .behindWindow
        view.state = .active
        view.maskImage = Self.roundedMask(cornerRadius: cornerRadius)
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}

    /// 一张能拉伸的小圆角图：四个角保持圆角，中间部分随视图大小拉伸。
    private static func roundedMask(cornerRadius: CGFloat) -> NSImage {
        let edge = cornerRadius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: cornerRadius, yRadius: cornerRadius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: cornerRadius, left: cornerRadius, bottom: cornerRadius, right: cornerRadius)
        image.resizingMode = .stretch
        return image
    }
}

/// 把相邻的几块玻璃放进同一个容器：系统一次性画完，更省电也更流畅，靠近时还会自然地融在一起。
struct TidyGlassGroup<Content: View>: View {
    var spacing: CGFloat = 4
    @ViewBuilder let content: Content

    var body: some View {
        #if compiler(>=6.2)
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
        #else
        content
        #endif
    }
}
