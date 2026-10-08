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

    private func frostedGlass<S: Shape>(in shape: S, tint: Color?) -> some View {
        background {
            ZStack {
                shape.fill(.ultraThinMaterial)
                if let tint {
                    shape.fill(tint)
                }
                shape.stroke(Color.white.opacity(0.25), lineWidth: 0.5)
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
