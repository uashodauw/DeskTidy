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

    private enum Area {
        case hidden, running, settings
    }

    /// 一次只展开一个，面板才不会被拉得很长。默认全部收起。
    @State private var expanded: Area?

    private let rowHeight: CGFloat = 26
    private let maxListHeight: CGFloat = 156

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

            TidyGlassGroup(spacing: 8) {
                VStack(spacing: 8) {
                    Button(action: onClean) {
                        Label("一键清理", systemImage: "wand.and.stars")
                    }
                    .buttonStyle(TidyButtonStyle(isLarge: true))

                    Button(action: onRestore) {
                        Label("一键恢复", systemImage: "arrow.uturn.backward")
                    }
                    .buttonStyle(TidyButtonStyle(isLarge: true))
                    .disabled(!cleanup.canRestore)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Divider()
                    .padding(.bottom, 4)
                hiddenAppsSection
                runningAppsSection
                settingsSection
            }

            Button("退出") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
        .tidyWindowGlass(cornerRadius: 18)
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
            // 提示只占一行：行数一变，整个面板就会跟着变高变矮，看起来一跳一跳的
            Text(scenes.selectedScene == nil ? "场景 · 未选，只保留当前在用的应用" : "场景 · 再点一次取消")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .contentTransition(.opacity)
            // 系统的分段选择器不能取消选中，所以用一排按钮
            TidyGlassGroup(spacing: 4) {
                HStack(spacing: 4) {
                    ForEach(scenes.scenes) { scene in
                        Button(scene.name) {
                            withAnimation(TidyMotion.layout) { scenes.toggle(scene) }
                        }
                            .buttonStyle(TidyButtonStyle(isSelected: scene.id == scenes.selectedID))
                    }
                }
            }
        }
    }

    // MARK: - 可折叠的区域

    private func sectionHeader(_ title: String, detail: String, section: Area) -> some View {
        SectionHeader(title: title, detail: detail, isExpanded: expanded == section) {
            withAnimation(TidyMotion.layout) {
                expanded = expanded == section ? nil : section
            }
        }
    }

    private var sectionTransition: AnyTransition {
        .asymmetric(
            insertion: .opacity.combined(with: .offset(y: -6)),
            removal: .opacity
        )
    }

    @ViewBuilder
    private var hiddenAppsSection: some View {
        let hiddenApps = cleanup.hiddenApps(in: runningApps.apps)
        if !hiddenApps.isEmpty {
            sectionHeader("已收起", detail: "\(hiddenApps.count) 个", section: .hidden)
            if expanded == .hidden {
                VStack(alignment: .leading, spacing: 2) {
                    Text("点一下叫回来")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    appList(hiddenApps) { app in
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
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(sectionTransition)
            }
        }
    }

    private var runningAppsSection: some View {
        Group {
            sectionHeader("正在运行", detail: "\(runningApps.apps.count) 个", section: .running)
            if expanded == .running {
                VStack(alignment: .leading, spacing: 2) {
                    Text(runningAppsHint)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2, reservesSpace: true)
                        .contentTransition(.opacity)
                    if runningApps.apps.isEmpty {
                        Text("没有其他正在运行的应用")
                            .font(.callout)
                            .foregroundStyle(.tertiary)
                    } else {
                        appList(runningApps.apps) { app in
                            HStack(spacing: 8) {
                                // 勾选框放在最左边：右边缘会被滚动条盖住
                                if scenes.selectedScene != nil {
                                    Toggle("在当前场景中保留", isOn: keptBinding(for: app))
                                        .toggleStyle(.checkbox)
                                        .labelsHidden()
                                        .transition(.opacity)
                                }
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
                        }
                    }
                }
                .transition(sectionTransition)
            }
        }
    }

    private var settingsSection: some View {
        Group {
            sectionHeader("设置", detail: "", section: .settings)
            if expanded == .settings {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle("清理时播放提示音", isOn: $settings.soundEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)

                    settingPicker("多久没用算很久", selection: $settings.idleThreshold, options: IdleThreshold.allCases, label: \.label)

                    settingPicker(
                        "很久没用的提醒",
                        selection: $settings.idleReminderFrequency,
                        options: IdleReminderFrequency.allCases,
                        label: \.label
                    )

                    HStack {
                        Text("清理快捷键")
                            .font(.callout)
                        Spacer()
                        KeyboardShortcuts.Recorder(for: .cleanDesktop)
                            .controlSize(.small)
                    }
                }
                .padding(.vertical, 4)
                .transition(sectionTransition)
            }
        }
    }

    private func settingPicker<Option: Hashable & Identifiable>(
        _ title: String,
        selection: Binding<Option>,
        options: [Option],
        label: KeyPath<Option, String>
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.callout)
            Picker(title, selection: selection) {
                ForEach(options) { option in
                    Text(option[keyPath: label]).tag(option)
                }
            }
            .labelsHidden()
            .controlSize(.small)
        }
    }

    // MARK: - 列表

    private func appList<Row: View>(_ apps: [RunningApp], @ViewBuilder row: @escaping (RunningApp) -> Row) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(apps) { app in
                    row(app)
                        .frame(height: rowHeight)
                        // 给右边浮出来的滚动条留位置
                        .padding(.trailing, 14)
                }
            }
        }
        .frame(height: min(CGFloat(apps.count) * rowHeight, maxListHeight))
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

    private var runningAppsHint: String {
        if let scene = scenes.selectedScene {
            return "打勾 = 在「\(scene.name)」场景中保留；右边是上次使用时间"
        }
        return "选一个场景，才能勾选要保留的应用；右边是上次使用时间"
    }
}

/// 可折叠区域的标题行：箭头转动展开，鼠标移上去有淡淡的高亮，展开中的那一行垫一层玻璃。
private struct SectionHeader: View {
    let title: String
    let detail: String
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
                    .frame(width: 12)
                Text(title)
                    .font(.callout)
                Spacer()
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 24)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.primary.opacity(isHovered && !isExpanded ? 0.06 : 0))
                    Color.clear
                        .tidyGlass(in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .opacity(isExpanded ? 1 : 0)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(TidyMotion.color) { isHovered = hovering }
        }
    }
}
