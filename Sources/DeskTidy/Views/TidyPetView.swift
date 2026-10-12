import SwiftUI
import DeskTidyCore

/// 面板标题旁边的小桌宠"团子"：一团软软的小云，头上顶着一颗星星。
/// 只用来看：点击和悬停都会直接穿过它，不会挡住或误触任何按钮。
struct TidyPetView: View {
    let mood: PetMood

    @State private var inhale = false
    @State private var blinking = false
    @State private var hopping = false

    private static let size = CGSize(width: 34, height: 28)
    private static let breathDuration: Double = 1.6
    private static let eyeColor = Color(white: 0.2)
    private static let accent = Color(red: 0.25, green: 0.78, blue: 0.82)

    var body: some View {
        ZStack {
            Ellipse()
                .fill(LinearGradient(
                    colors: [Color.white, Color(red: 0.84, green: 0.92, blue: 0.99)],
                    startPoint: .top,
                    endPoint: .bottom
                ))
                .overlay(Ellipse().stroke(Color.white.opacity(0.9), lineWidth: 0.6))
                .shadow(color: .black.opacity(0.18), radius: 1.5, y: 1)
                .frame(width: 30, height: 24)
                .offset(y: 2)

            eyes
            cheeks
            mouth

            Image(systemName: "sparkle")
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(Self.accent)
                .offset(x: 9, y: -11)

            if mood == .dizzy {
                Image(systemName: "drop.fill")
                    .font(.system(size: 6))
                    .foregroundStyle(Self.accent.opacity(0.85))
                    .offset(x: -14, y: -5)
                    .transition(.opacity)
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
        .scaleEffect(x: inhale ? 1.03 : 1, y: inhale ? 0.95 : 1, anchor: .bottom)
        .rotationEffect(.degrees(mood == .dizzy ? (inhale ? 5 : -5) : 0), anchor: .bottom)
        .offset(y: hopping ? -4 : 0)
        .animation(TidyMotion.layout, value: mood)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task { await breathe() }
        .task { await blinkNow() }
        .onChange(of: mood) { newMood in
            if newMood == .happy { hop() }
        }
    }

    @ViewBuilder
    private var eyes: some View {
        HStack(spacing: 8) {
            ForEach(0..<2, id: \.self) { _ in eye }
        }
        .offset(y: 1)
    }

    @ViewBuilder
    private var eye: some View {
        switch mood {
        case .happy:
            Arc(bulgesUp: true)
                .stroke(Self.eyeColor, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: 5, height: 2.5)
        case .calm:
            Capsule()
                .fill(Self.eyeColor)
                .frame(width: 3, height: 4)
                .scaleEffect(y: blinking ? 0.15 : 1)
        case .dizzy:
            Circle()
                .stroke(Self.eyeColor, lineWidth: 1.1)
                .overlay(Circle().fill(Self.eyeColor).frame(width: 1.4, height: 1.4))
                .frame(width: 4.5, height: 4.5)
        }
    }

    private var cheeks: some View {
        HStack(spacing: 14) {
            ForEach(0..<2, id: \.self) { _ in
                Ellipse()
                    .fill(Color(red: 1, green: 0.62, blue: 0.66).opacity(mood == .dizzy ? 0.25 : 0.5))
                    .frame(width: 5, height: 3)
            }
        }
        .offset(y: 5)
    }

    @ViewBuilder
    private var mouth: some View {
        switch mood {
        case .happy:
            Arc(bulgesUp: false)
                .stroke(Self.eyeColor, style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                .frame(width: 5, height: 2.5)
                .offset(y: 6)
        case .calm:
            Arc(bulgesUp: false)
                .stroke(Self.eyeColor, style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
                .frame(width: 3.5, height: 1.5)
                .offset(y: 6)
        case .dizzy:
            Ellipse()
                .fill(Self.eyeColor)
                .frame(width: 2.6, height: 2.2)
                .offset(y: 6.5)
        }
    }

    // MARK: - 动作

    /// 状态隔一会儿切换一次，不用一直跑的动画：面板收起后几乎不占电脑资源
    private func breathe() async {
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: Self.breathDuration)) { inhale.toggle() }
            try? await Task.sleep(nanoseconds: UInt64(Self.breathDuration * 1_000_000_000))
        }
    }

    private func blinkNow() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.5...5.5) * 1_000_000_000))
            withAnimation(.easeOut(duration: 0.06)) { blinking = true }
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeIn(duration: 0.08)) { blinking = false }
        }
    }

    /// 桌面变清爽时开心地蹦一下
    private func hop() {
        withAnimation(.spring(response: 0.22, dampingFraction: 0.5)) { hopping = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) { hopping = false }
        }
    }
}

/// 一段弧线：bulgesUp 为 true 时向上拱（笑眯眯的眼睛），false 时向下弯（微笑的嘴）
private struct Arc: Shape {
    let bulgesUp: Bool

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let y = bulgesUp ? rect.maxY : rect.minY
        path.move(to: CGPoint(x: rect.minX, y: y))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: y),
            control: CGPoint(x: rect.midX, y: bulgesUp ? rect.minY - rect.height : rect.maxY + rect.height)
        )
        return path
    }
}
