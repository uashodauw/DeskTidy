import AppKit
import SwiftUI
import DeskTidyCore

struct PanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(AppInfo.displayName, systemImage: "sparkles")
                .font(.headline)

            Text("脚手架搭建成功，功能开发中。")
                .foregroundStyle(.secondary)

            Text("版本 \(AppInfo.version)")
                .font(.caption)
                .foregroundStyle(.tertiary)

            Divider()

            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
    }
}
