import AppKit
import SwiftUI
import DeskTidyCore

struct PanelView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(AppInfo.displayName, systemImage: "sparkles")
                    .font(.headline)
                Spacer()
                Text("v\(AppInfo.version)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Button {
            } label: {
                Label("一键清理", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button {
            } label: {
                Label("一键恢复", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)

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
