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
    let onOpen: (RunningApp) -> Void
    let onQuit: (RunningApp) -> Void

    private enum Area {
        case hidden, running, settings
    }

    /// 一次只展开一个，面板才不会被拉得很长。默认全部收起。
    @State private var expanded: Area?
    /// 已经请求退出、还没真正退出的应用（可能正在问用户要不要保存）
    @State private var quittingIDs: Set<String> = []
    /// 用户在"是否保存"里点了取消时，应用不会退出；过这么久就恢复正常显示
    private let quittingTimeout: TimeInterval = 4

    private let rowHeight: CGFloat = 26
    private let maxListHeight: CGFloat = 156
    /// 设置项越加越多，全部摊开会比面板窗口还高，底边被切掉；超过这个高度就在区域里滚动
    private let maxSettingsHeight: CGFloat = 280

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                // 明确指定纯白：用 .primary 这类系统颜色时，玻璃会让文字和背景"融合"，边缘发虚。
                // 阴影不能模糊（radius 0）：只往下错开 1 点，让白字在浅色玻璃上也看得清，边缘依然锐利。
                Label(AppInfo.brandName, systemImage: "sparkles")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(Color.white)
                    .shadow(color: .black.opacity(0.35), radius: 0, x: 0, y: 1)
                Spacer()
                Text("v\(AppInfo.version)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    .foregroundStyle(.secondary)
            }
        }
        .font(.callout)
    }

    private let sceneColumns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 3)

    private var scenePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            // 提示只占一行：行数一变，整个面板就会跟着变高变矮，看起来一跳一跳的
            Text(scenes.selectedScene == nil ? "场景 · 未选，只保留当前在用的应用" : "场景 · 再点一次取消")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .contentTransition(.opacity)
            // 系统的分段选择器不能取消选中，所以用按钮；一行 3 个，自定义场景多了就排到第二行
            TidyGlassGroup(spacing: 4) {
                LazyVGrid(columns: sceneColumns, spacing: 4) {
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
            // 设置收起后输入框还在（只是看不见），光标留在里面的话，打字会打进看不见的框里
            if expanded == .settings {
                NSApp.keyWindow?.makeFirstResponder(nil)
            }
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
                        .foregroundStyle(.secondary)
                    appList(hiddenApps) { app in
                        Button {
                            onBringBack(app)
                        } label: {
                            HoverRow { _ in
                                HStack(spacing: 8) {
                                    appIcon(app)
                                    Text(app.name)
                                        .lineLimit(1)
                                    Spacer()
                                    Image(systemName: "arrow.up.forward.app")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .transition(sectionTransition)
            }
        }
    }

    private var runningAppsByRecentUse: [RunningApp] {
        RunningAppList.sortedByRecentUse(
            runningApps.apps,
            currentBundleID: frontmostApp.current?.bundleID,
            lastUsed: usage.lastUsed
        )
    }

    private var runningAppsSection: some View {
        Group {
            sectionHeader("正在运行", detail: "\(runningApps.apps.count) 个", section: .running)
            if expanded == .running {
                VStack(alignment: .leading, spacing: 2) {
                    Text(runningAppsHint)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                        .contentTransition(.opacity)
                    if runningApps.apps.isEmpty {
                        Text("没有其他正在运行的应用")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    } else {
                        appList(runningAppsByRecentUse) { app in
                            HoverRow { isHovered in
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
                                    runningRowTrailing(app, isHovered: isHovered)
                                }
                            }
                            // 只认双击：勾选框自己会接住单击，单击行的其他地方什么都不做，也不会误打开。
                            // 不给每一行挂悬停提示：滚动时系统要不停更新它们，会卡；上面的说明文字已经讲了双击打开
                            .onTapGesture(count: 2) { onOpen(app) }
                        }
                    }
                }
                .transition(sectionTransition)
            }
        }
    }

    /// 行的右边：平时显示上次使用时间；鼠标移上来换成退出按钮；请求退出后显示"退出中…"。
    /// 退出按钮只在悬停时出现，避免随手一点就把应用关了。
    ///
    /// 时间和退出按钮一直都在，悬停只切换谁看得见：滑动时每经过一行就新建、销毁一次按钮，开销很大。
    /// 退出按钮不挂悬停提示，同样是因为滑动时系统要不停更新它们；上面的说明文字已经讲了点 ✕ 退出。
    @ViewBuilder
    private func runningRowTrailing(_ app: RunningApp, isHovered: Bool) -> some View {
        if quittingIDs.contains(app.bundleID) {
            Text("退出中…")
                .font(.caption)
                .foregroundStyle(.secondary)
                .transition(.opacity)
        } else {
            let showsQuit = isHovered && QuitRules.canQuitFromPanel(app)
            ZStack(alignment: .trailing) {
                if let lastUsed = lastUsedText(for: app) {
                    Text(lastUsed)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .opacity(showsQuit ? 0 : 1)
                }
                if QuitRules.canQuitFromPanel(app) {
                    Button {
                        requestQuit(app)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                    .opacity(showsQuit ? 1 : 0)
                    .allowsHitTesting(showsQuit)
                }
            }
            .transition(.opacity)
        }
    }

    private func requestQuit(_ app: RunningApp) {
        withAnimation(TidyMotion.color) { _ = quittingIDs.insert(app.bundleID) }
        onQuit(app)
        DispatchQueue.main.asyncAfter(deadline: .now() + quittingTimeout) {
            withAnimation(TidyMotion.color) { _ = quittingIDs.remove(app.bundleID) }
        }
    }

    /// 设置里全是系统控件（输入框、下拉菜单、开关、快捷键录制框）。如果每次展开才新建，
    /// 它们要等挂到窗口上之后才画出灰色底，而且不跟着淡入动画走，看起来就是"延迟才变灰"；
    /// 一次新建十来个还会卡住展开动画。所以面板一出来就建好，收起时只是把高度压成 0、藏起来。
    private var settingsSection: some View {
        let isOpen = expanded == .settings
        return Group {
            sectionHeader("设置", detail: "", section: .settings)
            CappedScrollView(maxHeight: maxSettingsHeight) {
                settingsContent
            }
            // 只裁掉、不调透明度：系统控件跟不上透明度渐变，会先整块亮一下再变淡，看起来就是闪
            .frame(height: isOpen ? nil : 0, alignment: .top)
            .clipped()
            .allowsHitTesting(isOpen)
            .accessibilityHidden(!isOpen)
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            SceneEditorView(scenes: scenes)

            Toggle("清理时播放提示音", isOn: $settings.soundEnabled)
                .toggleStyle(.switch)
                .controlSize(.small)

            if settings.soundEnabled && !settings.availableCleanSounds.isEmpty {
                settingPicker(
                    "提示音（选中即试听）",
                    selection: $settings.cleanSound,
                    options: settings.availableCleanSounds,
                    label: \.label
                )
                .transition(.opacity)
            }

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

            HStack {
                Text("打开面板快捷键")
                    .font(.callout)
                Spacer()
                KeyboardShortcuts.Recorder(for: .togglePanel)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
        // 给右边浮出来的滚动条留位置
        .padding(.trailing, 10)
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
            return "双击打开，悬停点 ✕ 退出应用；打勾 = 在「\(scene.name)」中保留"
        }
        return "双击打开，悬停点 ✕ 退出应用；选一个场景才能勾选保留"
    }
}

/// 内容不高时和普通的一列一样高；超过 maxHeight 就停在 maxHeight，多出来的在里面滚动。
/// ScrollView 自己不会按内容决定高度，所以先量出内容有多高。
private struct CappedScrollView<Content: View>: View {
    let maxHeight: CGFloat
    @ViewBuilder let content: Content

    @State private var contentHeight: CGFloat?

    var body: some View {
        ScrollView(.vertical) {
            content
                .background(GeometryReader { proxy in
                    Color.clear.preference(key: ContentHeightKey.self, value: proxy.size.height)
                })
        }
        .frame(height: min(contentHeight ?? maxHeight, maxHeight))
        .onPreferenceChange(ContentHeightKey.self) { height in
            contentHeight = height
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// 列表里的一行：鼠标一移上去就高亮，让人马上知道选中了这一行。
/// 把"鼠标在不在这一行上"交给内容，内容可以据此显示额外的按钮（比如退出）。
///
/// 高亮不做渐变动画：快速滑动时一行行从鼠标下面滑过，每行都会"进入、离开"一次，
/// 每次都播放动画的话，一秒要同时跑几十个动画，会卡。直接切换几乎不花力气，反馈也更快。
private struct HoverRow<Content: View>: View {
    @ViewBuilder let content: (Bool) -> Content

    @State private var isHovered = false

    var body: some View {
        content(isHovered)
            .padding(.horizontal, 4)
            .frame(maxHeight: .infinity)
            .background(
                // 用会和玻璃混色的 .primary：换成固定颜色在玻璃上淡得几乎看不出来，用户感觉不到选中了
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.primary.opacity(isHovered ? 0.07 : 0))
            )
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

/// 可折叠区域的标题行：箭头转动展开，鼠标移上去有淡淡的高亮，展开中的那一行垫一层灰底。
private struct SectionHeader: View {
    let title: String
    let detail: String
    let isExpanded: Bool
    let action: () -> Void

    @State private var isHovered = false

    private var backgroundOpacity: Double {
        if isExpanded { return 0.09 }
        return isHovered ? 0.06 : 0
    }

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
            // 展开时的底色不用玻璃：系统的玻璃不跟着透明度渐变走，点开时会"啪"地一下冒出来，看起来像闪。
            // 普通的半透明底色可以平滑地淡入淡出。
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.primary.opacity(backgroundOpacity))
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(TidyMotion.color) { isHovered = hovering }
        }
    }
}
