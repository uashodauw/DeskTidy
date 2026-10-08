import AppKit
import SwiftUI
import DeskTidyCore

struct IdleAppsView: View {
    let apps: [RunningApp]
    let threshold: IdleThreshold
    let icon: (RunningApp) -> NSImage?
    let lastUsed: (RunningApp) -> Date?
    let onDismiss: () -> Void

    private let rowHeight: CGFloat = 26
    private let maxListHeight: CGFloat = 240

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("超过 \(threshold.shortLabel)没用过，退出它们能让电脑更轻快。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(apps) { app in
                        HStack(spacing: 8) {
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
                Button("知道了", action: onDismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
