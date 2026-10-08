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
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .frame(height: rowHeight)
                        .padding(.trailing, 14)
                    }
                }
            }
            .frame(height: min(CGFloat(apps.count) * rowHeight, maxListHeight))

            HStack {
                Spacer()
                Button("暂不退出", action: onDismiss)
                    .keyboardShortcut(.cancelAction)
                Button(quitTitle) {
                    onQuit(selection.appsToQuit(from: apps))
                }
                .disabled(selection.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
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
