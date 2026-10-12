import SwiftUI
import DeskTidyCore

/// 番茄钟用到的颜色和字体，面板、小时钟、休息玻璃共用，看起来是同一个东西。
enum FocusStyle {
    /// 专注用系统橙色（和 iPhone 时钟里的计时器一样），休息用系统薄荷绿（和"健康""正念"一样让人放松）
    static func tint(for phase: FocusPhase?) -> Color {
        phase?.isBreak == true ? Color.mint : Color.orange
    }

    /// 倒计时数字：圆体 + 等宽数字。等宽才不会在数字跳动时左右晃。
    static func clockFont(size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        .system(size: size, weight: weight, design: .rounded).monospacedDigit()
    }

    static func title(for timer: FocusTimer) -> String {
        switch timer.state {
        case .idle:
            return "专注"
        case .running(let phase, _):
            return phase.isBreak ? "休息中" : "专注中"
        case .paused:
            return "已暂停"
        case .finished(let phase, _):
            return phase.isBreak ? "休息结束" : "专注完成"
        }
    }

    static func symbol(for phase: FocusPhase?) -> String {
        phase?.isBreak == true ? "cup.and.saucer.fill" : "timer"
    }
}

/// 进度环：底下一圈淡色，上面一段实色从 12 点方向顺时针走，和 iPhone 计时器、健身圆环的样子一致。
struct FocusRing: View {
    let progress: Double
    let tint: Color
    var lineWidth: CGFloat = 3

    var body: some View {
        ZStack {
            Circle()
                .stroke(tint.opacity(0.22), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, progress))
                .stroke(tint, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .padding(lineWidth / 2)
    }
}

/// 圆形的玻璃小图标按钮（暂停、继续、结束），和面板里的玻璃按钮是同一种玻璃
struct FocusIconButtonStyle: ButtonStyle {
    var size: CGFloat = 26
    var tint: Color?

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.42, weight: .semibold))
            .foregroundStyle(tint == nil ? Color.primary : Color.white)
            .frame(width: size, height: size)
            .contentShape(Circle())
            .tidyGlass(in: Circle(), tint: tint, interactive: true)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(TidyMotion.press, value: configuration.isPressed)
    }
}

/// 面板里"一键恢复"下面的一行：没开始时是"开始专注"按钮，计时中显示进度、剩余时间和操作按钮。
/// 单独订阅 FocusModel：每秒刷新时只重画这一行，不连累整个面板。
struct FocusPanelRow: View {
    @ObservedObject var focus: FocusModel
    let onStartFocus: () -> Void

    var body: some View {
        if focus.timer.isActive {
            VStack(alignment: .leading, spacing: 6) {
                activeRow
                meetingToggle
            }
        } else {
            Button(action: onStartFocus) {
                Label("开始专注 \(focus.focusMinutes) 分钟", systemImage: "timer")
            }
            .buttonStyle(TidyButtonStyle())
        }
    }

    private var activeRow: some View {
        let timer = focus.timer
        let tint = FocusStyle.tint(for: timer.phase)
        return HStack(spacing: 10) {
            FocusRing(progress: focus.progress, tint: tint, lineWidth: 3)
                .overlay {
                    Image(systemName: FocusStyle.symbol(for: timer.phase))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(tint)
                }
                .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(FocusStyle.title(for: timer))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(statusText(for: timer))
                    .font(FocusStyle.clockFont(size: 17))
            }
            Spacer(minLength: 4)
            HStack(spacing: 6) {
                primaryButton(for: timer)
                Button(action: focus.stop) {
                    Image(systemName: "xmark")
                }
                .buttonStyle(FocusIconButtonStyle())
                .help("结束计时")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    /// 开会、共享屏幕时打开：休息不铺满屏幕，免得在别人面前突然盖住屏幕
    private var meetingToggle: some View {
        HStack(spacing: 6) {
            Image(systemName: "person.2.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("开会模式：休息时不铺满屏幕")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 4)
            Toggle("开会模式", isOn: $focus.meetingMode)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 10)
    }

    private func statusText(for timer: FocusTimer) -> String {
        switch timer.state {
        case .finished(let phase, _):
            return phase.isBreak ? "开始下一轮？" : "该休息了"
        default:
            return focus.remainingText
        }
    }

    @ViewBuilder
    private func primaryButton(for timer: FocusTimer) -> some View {
        switch timer.state {
        case .running:
            Button(action: focus.pause) { Image(systemName: "pause.fill") }
                .buttonStyle(FocusIconButtonStyle())
                .help("暂停")
        case .paused:
            Button(action: focus.resume) { Image(systemName: "play.fill") }
                .buttonStyle(FocusIconButtonStyle())
                .help("继续")
        case .finished(let phase, _):
            if phase.isBreak {
                Button(action: focus.startFocus) { Image(systemName: "play.fill") }
                    .buttonStyle(FocusIconButtonStyle(tint: FocusStyle.tint(for: .focus)))
                    .help("开始下一轮专注")
            } else {
                Button(action: focus.startBreak) { Image(systemName: "cup.and.saucer.fill") }
                    .buttonStyle(FocusIconButtonStyle(tint: FocusStyle.tint(for: .shortBreak)))
                    .help("开始休息")
            }
        case .idle:
            EmptyView()
        }
    }
}
