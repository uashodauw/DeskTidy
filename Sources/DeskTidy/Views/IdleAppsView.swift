import AppKit
import SwiftUI
import DeskTidyCore

struct IdleAppsView: View {
    let apps: [RunningApp]
    let threshold: IdleThreshold
    let icon: (RunningApp) -> NSImage?
    let lastUsed: (RunningApp) -> Date?
    let onQuit: ([RunningApp]) -> Void
    let onDismiss: () -> Void

    @State private var selection = QuitSelection()

    private let rowHeight: CGFloat = 26
    private let maxListHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                WindowCloseButton(action: onDismiss)
                Text("这些应用很久没用了")
                    .font(.headline)
            }
            Text("超过 \(threshold.shortLabel)没用过。勾选想退出的应用，有没保存的内容时它会先问你。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(apps) { app in
                        HStack(spacing: 8) {
                            // 勾选框放在最左边：右边缘会被滚动条盖住
                            Toggle("退出 \(app.name)", isOn: selectedBinding(for: app))
                                .toggleStyle(.checkbox)
                                .labelsHidden()
                            if let image = icon(app) {
                                Image(nsImage: image)
                                    .resizable()
                                    .frame(width: 18, height: 18)
                            }
                            Text(app.name)
                                .lineLimit(1)
                            Spacer()
                            if let date = lastUsed(app) {
                                Text(RelativeTime.describe(date))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(height: rowHeight)
                        .padding(.trailing, 14)
                    }
                }
            }
            .frame(height: min(CGFloat(apps.count) * rowHeight, maxListHeight))

            TidyGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    Button("暂不退出", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(TidyButtonStyle())
                    Button(quitTitle) {
                        onQuit(selection.appsToQuit(from: apps))
                    }
                    .buttonStyle(TidyButtonStyle())
                    .disabled(selection.isEmpty)
                }
            }
        }
        .padding(16)
        .frame(width: 300)
        .tidyWindowGlass(cornerRadius: 18)
    }

    private var quitTitle: String {
        let count = selection.appsToQuit(from: apps).count
        return count == 0 ? "退出所选应用" : "退出所选应用（\(count)）"
    }

    private func selectedBinding(for app: RunningApp) -> Binding<Bool> {
        Binding(
            get: { selection.isSelected(app) },
            set: { selection.setSelected(app, $0) }
        )
    }
}

/// 仿 macOS 窗口左上角的红色关闭按钮，悬停时显示 ×
private struct WindowCloseButton: View {
    let action: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(Color(red: 1.0, green: 0.37, blue: 0.34))
                .overlay(Circle().stroke(Color.black.opacity(0.12), lineWidth: 0.5))
                .overlay {
                    Image(systemName: "xmark")
                        .font(.system(size: 6.5, weight: .heavy))
                        .foregroundStyle(Color.black.opacity(0.55))
                        .opacity(isHovered ? 1 : 0)
                }
                .frame(width: 12, height: 12)
                .contentShape(Circle().inset(by: -4))
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(TidyMotion.color) { isHovered = hovering }
        }
        .help("关闭")
        .accessibilityLabel("关闭")
    }
}
