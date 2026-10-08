import AppKit
import KeyboardShortcuts
import SwiftUI
import DeskTidyCore

struct PanelView: View {
    @ObservedObject var runningApps: RunningAppsModel
    @ObservedObject var frontmostApp: FrontmostAppModel
    @ObservedObject var cleanup: CleanupController
    @ObservedObject var scenes: SceneModel
    @ObservedObject var settings: SettingsModel
    let usage: UsageModel
    let onClean: () -> Void
    let onRestore: () -> Void
    let onBringBack: (RunningApp) -> Void

    private let rowHeight: CGFloat = 26
    private let maxListHeight: CGFloat = 240

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

            currentAppRow

            scenePicker

            Button(action: onClean) {
                Label("一键清理", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button(action: onRestore) {
                Label("一键恢复", systemImage: "arrow.uturn.backward")
                    .frame(maxWidth: .infinity)
            }
            .controlSize(.large)
            .disabled(!cleanup.canRestore)

            hiddenAppsSection

            Divider()

            runningAppsSection

            Divider()

            Toggle("清理时播放提示音", isOn: $settings.soundEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack {
                Text("清理快捷键")
                    .font(.callout)
                Spacer()
                KeyboardShortcuts.Recorder(for: .cleanDesktop)
                    .controlSize(.small)
            }

            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
    }

    private var currentAppRow: some View {
        HStack(spacing: 6) {
            Text("当前在用：")
                .foregroundStyle(.secondary)
            if let app = frontmostApp.current {
                if let icon = runningApps.icon(for: app) {
                    Image(nsImage: icon)
                        .resizable()
                        .frame(width: 16, height: 16)
                }
                Text(app.name)
                    .fontWeight(.medium)
                    .lineLimit(1)
            } else {
                Text("未知")
                    .foregroundStyle(.tertiary)
            }
        }
        .font(.callout)
    }

    private var scenePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("场景")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("场景", selection: $scenes.selectedID) {
                ForEach(scenes.scenes) { scene in
                    Text(scene.name).tag(scene.id)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    @ViewBuilder
    private var hiddenAppsSection: some View {
        let hiddenApps = cleanup.hiddenApps(in: runningApps.apps)
        if !hiddenApps.isEmpty {
            Divider()
            VStack(alignment: .leading, spacing: 6) {
                Text("已收起（\(hiddenApps.count)）· 点一下叫回来")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(hiddenApps) { app in
                            Button {
                                onBringBack(app)
                            } label: {
                                HStack(spacing: 8) {
                                    appIcon(app)
                                    Text(app.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .foregroundStyle(.secondary)
                                }
                                .frame(height: rowHeight)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .frame(height: min(CGFloat(hiddenApps.count) * rowHeight, maxListHeight))
            }
        }
    }

    @ViewBuilder
    private func appIcon(_ app: RunningApp) -> some View {
        if let icon = runningApps.icon(for: app) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: 18, height: 18)
        }
    }

    private func keptBinding(for app: RunningApp) -> Binding<Bool> {
        Binding(
            get: { scenes.isKept(app) },
            set: { scenes.setKept(app, $0) }
        )
    }

    private func lastUsedText(for app: RunningApp) -> String? {
        if app.bundleID == frontmostApp.current?.bundleID {
            return "正在用"
        }
        return usage.lastUsed(app).map { RelativeTime.describe($0) }
    }

    private var runningAppsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("正在运行（\(runningApps.apps.count)）")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("打勾 = 在「\(scenes.selectedScene.name)」场景中保留；右边是上次使用时间")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if runningApps.apps.isEmpty {
                Text("没有其他正在运行的应用")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(runningApps.apps) { app in
                            HStack(spacing: 8) {
                                // 勾选框放在最左边：右边缘会被滚动条盖住
                                Toggle("在当前场景中保留", isOn: keptBinding(for: app))
                                    .toggleStyle(.checkbox)
                                    .labelsHidden()
                                appIcon(app)
                                Text(app.name)
                                    .lineLimit(1)
                                Spacer()
                                if let lastUsed = lastUsedText(for: app) {
                                    Text(lastUsed)
                                        .font(.caption)
                                        .foregroundStyle(.tertiary)
                                        .help("上次使用时间")
                                }
                            }
                            .frame(height: rowHeight)
                            // 给右边浮出来的滚动条留位置
                            .padding(.trailing, 14)
                        }
                    }
                }
                .frame(height: min(CGFloat(runningApps.apps.count) * rowHeight, maxListHeight))
            }
        }
    }
}
