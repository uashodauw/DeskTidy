import AppKit
import SwiftUI
import DeskTidyCore

struct PanelView: View {
    @ObservedObject var runningApps: RunningAppsModel
    @ObservedObject var frontmostApp: FrontmostAppModel
    @ObservedObject var cleanup: CleanupController
    @ObservedObject var scenes: SceneModel
    @ObservedObject var settings: SettingsModel
    let usage: UsageModel
    /// 不用 @ObservedObject：计时中每秒都在变，只让专注那一行订阅，整个面板不跟着每秒重画
    let focus: FocusModel
    let onStartFocus: () -> Void
    let onOpenSettings: () -> Void
    let onClean: () -> Void
    let onRestore: () -> Void
    let onBringBack: (RunningApp) -> Void
    let onOpen: (RunningApp) -> Void
    let onQuit: (RunningApp) -> Void

    private enum Area {
        case hidden, running
    }

    /// 一次只展开一个，面板才不会被拉得很长。默认全部收起。
    @State private var expanded: Area?
    /// 已经请求退出、还没真正退出的应用（可能正在问用户要不要保存）
    @State private var quittingIDs: Set<String> = []
    /// 用户在"是否保存"里点了取消时，应用不会退出；过这么久就恢复正常显示
    private let quittingTimeout: TimeInterval = 4

    private let rowHeight: CGFloat = 26
    private let maxListHeight: CGFloat = 156

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label(AppInfo.brandName, systemImage: "sparkles")
                    .font(.system(size: 15, weight: .bold))
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

            FocusPanelRow(focus: focus, onStartFocus: onStartFocus)

            VStack(alignment: .leading, spacing: 2) {
                Divider()
                    .padding(.bottom, 4)
                hiddenAppsSection
                runningAppsSection
            }

            HStack {
                Button("设置…", action: onOpenSettings)
                    .keyboardShortcut(",")
                Spacer()
                Button("退出") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }
        }
        .padding(16)
        .frame(width: 260, alignment: .leading)
        .modifier(PluginStyle(settings: settings, cornerRadius: 18))
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
