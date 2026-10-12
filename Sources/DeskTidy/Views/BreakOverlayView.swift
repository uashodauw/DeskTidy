import AppKit
import SwiftUI
import DeskTidyCore

/// 休息时铺满屏幕的毛玻璃。后面的窗口模糊可见，提醒用户离开屏幕一会儿；应用都还在原地。
/// 只有主屏幕显示时钟，其他屏幕只铺玻璃。
struct BreakOverlayView: View {
    @ObservedObject var focus: FocusModel
    let showsClock: Bool
    let tip: String
    let skipAvailableAt: Date
    let onSkip: () -> Void

    @State private var hasAppeared = false

    private var tint: Color { FocusStyle.tint(for: .shortBreak) }

    private var secondsUntilSkip: Int {
        Int(max(0, skipAvailableAt.timeIntervalSince(focus.now)).rounded(.up))
    }

    var body: some View {
        ZStack {
            FullScreenBlur()
            if showsClock {
                clock
                    // 角落的小时钟"长大"成这里的大时钟：从小弹到正常大小
                    .scaleEffect(hasAppeared ? 1 : 0.6)
                    .opacity(hasAppeared ? 1 : 0)
                skipButton
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(40)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) { hasAppeared = true }
        }
    }

    private var clock: some View {
        VStack(spacing: 28) {
            ZStack {
                FocusRing(progress: focus.progress, tint: tint, lineWidth: 10)
                    .frame(width: 260, height: 260)
                VStack(spacing: 6) {
                    Image(systemName: "cup.and.saucer.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(tint)
                    Text(focus.remainingText)
                        .font(FocusStyle.clockFont(size: 60, weight: .medium))
                    Text(focus.timer.phase == .longBreak ? "长休息" : "休息一下")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }
            Text(tip)
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var skipButton: some View {
        let canSkip = secondsUntilSkip == 0
        return VStack(alignment: .trailing, spacing: 8) {
            Button(canSkip ? "跳过休息" : "\(secondsUntilSkip) 秒后可以跳过", action: onSkip)
                .buttonStyle(TidyButtonStyle())
                .frame(width: 150)
                .disabled(!canSkip)
            Text("按 esc 也可以跳过")
                .font(.caption)
                .foregroundStyle(.secondary)
                .opacity(canSkip ? 1 : 0)
        }
    }
}

/// 整块屏幕的系统毛玻璃，和调度中心、登录界面的模糊是同一种
private struct FullScreenBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .fullScreenUI
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}
