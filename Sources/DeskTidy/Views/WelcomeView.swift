import AppKit
import KeyboardShortcuts
import SwiftUI
import DeskTidyCore

/// 第一次打开时的欢迎窗口。DeskTidy 没有窗口、也不在程序坞里，新用户不说就找不到它；
/// 菜单栏太满时图标还会被系统藏起来，所以要把另外两个入口也告诉用户。
struct WelcomeView: View {
    @ObservedObject var settings: SettingsModel
    let onOpenPanel: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(AppInfo.displayName)已经在运行")
                        .font(.title3.weight(.semibold))
                    Text("一键收起暂时不用的应用，让桌面清爽")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                tip(symbol: "sparkles", "点屏幕右上角菜单栏里的星星图标，打开面板。")
                tip(symbol: "keyboard", "也可以按 \(shortcutText(.togglePanel)) 打开面板，按 \(shortcutText(.cleanDesktop)) 直接一键清理。")
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("菜单栏里找不到星星？")
                    .font(.callout.weight(.semibold))
                Text("菜单栏放不下时，macOS 会把新装应用的图标藏起来。可以按上面的快捷键，或在「应用程序」里再打开一次 DeskTidy，面板会出现在屏幕右上角。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("想让星星一直看得见：按住 ⌘ 键，把它拖到菜单栏更靠右的位置。")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TidyGlassGroup(spacing: 8) {
                HStack(spacing: 8) {
                    Button("知道了", action: onDismiss)
                        .keyboardShortcut(.cancelAction)
                        .buttonStyle(TidyButtonStyle())
                    Button("打开面板看看", action: onOpenPanel)
                        .keyboardShortcut(.defaultAction)
                        .buttonStyle(TidyButtonStyle(isSelected: true))
                }
            }
        }
        .padding(20)
        .frame(width: 360)
        .modifier(PluginStyle(settings: settings, cornerRadius: 18))
    }

    private func tip(symbol: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func shortcutText(_ name: KeyboardShortcuts.Name) -> String {
        KeyboardShortcuts.getShortcut(for: name)?.description ?? "（未设置）"
    }
}
