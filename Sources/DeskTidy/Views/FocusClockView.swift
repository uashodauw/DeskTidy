import SwiftUI
import DeskTidyCore

/// 角落里的番茄钟小时钟。
/// 平时是一个小胶囊：进度环 + 剩余时间，鼠标放上去才露出按钮；到点时长大成一张卡片，给出下一步的选择。
/// 用的是和面板一样的玻璃、阴影、按钮和动画，看起来是从 DeskTidy 里"长"出来的。
struct FocusClockView: View {
    @ObservedObject var focus: FocusModel
    @ObservedObject var settings: SettingsModel

    @State private var isHovered = false
    @State private var isBumped = false

    private var isExpanded: Bool {
        if case .finished = focus.timer.state { return true }
        return false
    }

    private var cornerRadius: CGFloat { isExpanded ? 18 : 26 }
    private var tint: Color { FocusStyle.tint(for: focus.timer.phase) }

    var body: some View {
        Group {
            if isExpanded {
                expandedCard
            } else {
                compactPill
            }
        }
        .modifier(PluginStyle(settings: settings, cornerRadius: cornerRadius))
        .background { PanelShadow(cornerRadius: cornerRadius) }
        .scaleEffect(isBumped ? 1.06 : 1, anchor: .bottomTrailing)
        .onHover { hovering in
            withAnimation(TidyMotion.color) { isHovered = hovering }
        }
        .onChange(of: focus.attentionCount) { _ in bump() }
        .animation(TidyMotion.layout, value: isExpanded)
    }

    /// 到点时轻轻跳一下：先放大一点，再带回弹地落回去，和 iOS 通知出现时的感觉一样
    private func bump() {
        withAnimation(.spring(response: 0.18, dampingFraction: 0.5)) { isBumped = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) { isBumped = false }
        }
    }

    // MARK: - 小胶囊

    private var compactPill: some View {
        HStack(spacing: 10) {
            ring(size: 32, lineWidth: 3.5)
            VStack(alignment: .leading, spacing: 0) {
                Text(FocusStyle.title(for: focus.timer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(focus.remainingText)
                    .font(FocusStyle.clockFont(size: 20))
            }
            if isHovered {
                HStack(spacing: 6) {
                    compactPrimaryButton
                    Button(action: focus.stop) { Image(systemName: "xmark") }
                        .buttonStyle(FocusIconButtonStyle())
                        .help("结束计时")
                }
                .transition(.scale(scale: 0.6, anchor: .leading))
            }
        }
        .padding(.leading, 10)
        .padding(.trailing, 16)
        .padding(.vertical, 10)
        .fixedSize()
    }

    @ViewBuilder
    private var compactPrimaryButton: some View {
        let timer = focus.timer
        if timer.isPaused {
            Button(action: focus.resume) { Image(systemName: "play.fill") }
                .buttonStyle(FocusIconButtonStyle())
                .help("继续")
        } else if timer.phase?.isBreak == true {
            Button(action: focus.skipBreak) { Image(systemName: "forward.end.fill") }
                .buttonStyle(FocusIconButtonStyle())
                .help("跳过休息")
        } else {
            Button(action: focus.pause) { Image(systemName: "pause.fill") }
                .buttonStyle(FocusIconButtonStyle())
                .help("暂停")
        }
    }

    // MARK: - 到点时的卡片

    private var expandedCard: some View {
        let isBreakOver = focus.timer.phase?.isBreak == true
        return VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ring(size: 40, lineWidth: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(isBreakOver ? "休息结束" : "专注完成")
                        .font(.headline)
                    Text(isBreakOver
                         ? "准备好了就开始下一轮"
                         : "完成第 \(focus.timer.completedFocusRounds) 个番茄，休息 \(focus.nextBreakMinutes) 分钟吧")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            TidyGlassGroup(spacing: 8) {
                VStack(spacing: 8) {
                    if isBreakOver {
                        Button("开始专注 \(focus.focusMinutes) 分钟", action: focus.startFocus)
                            .buttonStyle(TidyButtonStyle(isSelected: true))
                        Button("结束", action: focus.stop)
                            .buttonStyle(TidyButtonStyle())
                    } else {
                        Button("开始休息", action: focus.startBreak)
                            .buttonStyle(TidyButtonStyle(isSelected: true))
                        HStack(spacing: 8) {
                            Button("再专注 5 分钟") { focus.extend(minutes: 5) }
                                .buttonStyle(TidyButtonStyle())
                            Button("跳过休息", action: focus.skipBreak)
                                .buttonStyle(TidyButtonStyle())
                        }
                    }
                }
            }
        }
        .padding(16)
        .frame(width: 260)
    }

    private func ring(size: CGFloat, lineWidth: CGFloat) -> some View {
        FocusRing(progress: focus.progress, tint: tint, lineWidth: lineWidth)
            .overlay {
                Image(systemName: FocusStyle.symbol(for: focus.timer.phase))
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: size, height: size)
    }
}
