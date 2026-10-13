import AppKit
import KeyboardShortcuts
import SwiftUI
import DeskTidyCore

// MARK: - iOS"设置"风格的积木

/// 设置窗口每一页的宽度：刚好放下一行"图标 + 名字 + 选择菜单"
let settingsPageWidth: CGFloat = 400

/// 一页设置：几组圆角卡片从上往下排。高度由内容决定，窗口跟着它变。
struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            content
        }
        .padding(20)
        .frame(width: settingsPageWidth, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }
}

/// 一组设置：上面一行灰色小标题，中间圆角卡片，下面一行灰色说明，和 iPhone"设置"里的分组一样。
struct SettingsGroup<Content: View>: View {
    var header: String?
    var footer: String?
    var footerColor: Color?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let header {
                Text(header)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.leading, 12)
            }
            VStack(spacing: 0) {
                content
            }
            .background(SettingsCardGlass())
            if let footer {
                Text(footer)
                    .font(.caption)
                    .foregroundStyle(footerColor.map { AnyShapeStyle($0) } ?? AnyShapeStyle(HierarchicalShapeStyle.secondary))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
            }
        }
    }
}

/// 设置卡片的底：一层很淡的白色让卡片从窗口玻璃上浮起来，但依然透得出后面；
/// 边缘用和窗口一样的高光（上亮下淡），不用一整圈灰线。
/// 不再套一层系统玻璃：玻璃叠玻璃在 macOS 26 上会发灰、发闷，切换标签淡入淡出时还会闪。
private struct SettingsCardGlass: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        shape
            .fill(Color.white.opacity(colorScheme == .dark ? 0.07 : 0.38))
            .overlay(shape.strokeBorder(TidyGlassEdge.gradient, lineWidth: 0.5))
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.05), radius: 3, y: 1)
    }
}

/// 卡片里的一行：左边彩色小图标、名字，右边放开关、选择菜单或快捷键框
struct SettingsRow<Accessory: View>: View {
    let title: String
    var symbol: String?
    var color: Color = .gray
    var showsDivider = true
    @ViewBuilder let accessory: Accessory

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 10) {
                if let symbol {
                    SettingsIcon(symbol: symbol, color: color)
                }
                // 没有名字的行（场景名字输入框）：右边的内容占满整行
                if !title.isEmpty {
                    Text(title)
                    Spacer(minLength: 12)
                }
                accessory
            }
            .padding(.horizontal, 12)
            .frame(minHeight: 38)
            if showsDivider {
                // 分隔线从文字开始，不穿过图标，和 iOS 一样
                Divider()
                    .padding(.leading, symbol == nil ? 12 : 42)
            }
        }
    }
}

/// iOS"设置"每一行前面的圆角方块彩色图标
struct SettingsIcon: View {
    let symbol: String
    let color: Color

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.white)
            .frame(width: 20, height: 20)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color.gradient)
            )
    }
}

/// 右边的选择菜单：只占需要的宽度，靠右对齐
struct SettingsMenu<Option: Hashable>: View {
    let title: String
    @Binding var selection: Option
    let options: [Option]
    let label: (Option) -> String

    var body: some View {
        Picker(title, selection: $selection) {
            ForEach(options, id: \.self) { option in
                Text(label(option)).tag(option)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .fixedSize()
    }
}

// MARK: - 窗口内容

enum SettingsTab: String, CaseIterable, Identifiable {
    case scenes, clean, focus, shortcuts

    var id: String { rawValue }

    var title: String {
        switch self {
        case .scenes: return "场景"
        case .clean: return "清理"
        case .focus: return "专注"
        case .shortcuts: return "快捷键"
        }
    }

    var symbol: String {
        switch self {
        case .scenes: return "square.stack.3d.up"
        case .clean: return "wand.and.stars"
        case .focus: return "timer"
        case .shortcuts: return "keyboard"
        }
    }
}

/// 设置窗口：左上角红色关闭按钮、标题，一排玻璃标签，下面是当前标签的内容。
struct SettingsRootView: View {
    @ObservedObject var scenes: SceneModel
    @ObservedObject var settings: SettingsModel
    let onClose: () -> Void

    /// 记住上次看的标签，下次打开还在这里
    @AppStorage("settingsTab") private var tab: SettingsTab = .scenes

    /// 换标签：旧的一页淡出、新的一页从稍微靠下的位置淡入，玻璃同时伸缩到新的高度
    private static let switchAnimation = Animation.easeInOut(duration: 0.26)

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                Text("设置")
                    .font(.headline)
                HStack {
                    WindowCloseButton(action: onClose)
                    Spacer()
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)

            TidyGlassGroup(spacing: 6) {
                HStack(spacing: 6) {
                    ForEach(SettingsTab.allCases) { item in
                        Button {
                            withAnimation(Self.switchAnimation) { tab = item }
                        } label: {
                            Label(item.title, systemImage: item.symbol)
                        }
                        .buttonStyle(TidyButtonStyle(isSelected: item == tab))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ZStack(alignment: .top) {
                ForEach(SettingsTab.allCases) { item in
                    page(for: item)
                        .opacity(item == tab ? 1 : 0)
                        .offset(y: item == tab ? 0 : 8)
                        // 没选中的页压成 0 高：玻璃只包住当前这一页
                        .frame(height: item == tab ? nil : 0, alignment: .top)
                        .clipped()
                        .allowsHitTesting(item == tab)
                        .accessibilityHidden(item != tab)
                }
            }
        }
        .frame(width: settingsPageWidth)
        .tidyWindowGlass(cornerRadius: SettingsWindowController.cornerRadius)
    }

    /// 四页一直都在（只是看不见）：每次切换才新建的话，系统控件要晚一拍才画出来，看起来会闪
    @ViewBuilder
    private func page(for tab: SettingsTab) -> some View {
        switch tab {
        case .scenes: SceneSettingsPage(scenes: scenes)
        case .clean: CleanSettingsPage(settings: settings)
        case .focus: FocusSettingsPage(settings: settings)
        case .shortcuts: ShortcutSettingsPage()
        }
    }
}

// MARK: - 四个标签页

struct CleanSettingsPage: View {
    @ObservedObject var settings: SettingsModel

    var body: some View {
        SettingsPage {
            SettingsGroup(header: "面板标题", footer: titleColorFooter) {
                SettingsRow(
                    title: "标题颜色",
                    symbol: "paintbrush.fill",
                    color: .blue,
                    showsDivider: settings.titleColorMode == .custom
                ) {
                    SettingsMenu(
                        title: "标题颜色",
                        selection: $settings.titleColorMode,
                        options: TitleColorMode.allCases,
                        label: \.label
                    )
                }
                if settings.titleColorMode == .custom {
                    SettingsRow(title: "浅色模式", symbol: "sun.max.fill", color: .orange) {
                        TitleColorWell(title: "浅色模式", color: $settings.titleColorLight)
                    }
                    SettingsRow(title: "深色模式", symbol: "moon.fill", color: .indigo, showsDivider: false) {
                        TitleColorWell(title: "深色模式", color: $settings.titleColorDark)
                    }
                }
            }

            SettingsGroup(header: "提示音", footer: "一键清理完成时播放。选一个声音会马上试听。") {
                SettingsRow(
                    title: "清理时播放提示音",
                    symbol: "speaker.wave.2.fill",
                    color: .pink,
                    showsDivider: showsSoundPicker
                ) {
                    Toggle("清理时播放提示音", isOn: $settings.soundEnabled)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
                if showsSoundPicker {
                    SettingsRow(title: "提示音", symbol: "music.note", color: .red, showsDivider: false) {
                        SettingsMenu(
                            title: "提示音",
                            selection: $settings.cleanSound,
                            options: settings.availableCleanSounds,
                            label: \.label
                        )
                    }
                }
            }

            SettingsGroup(header: "很久没用的应用", footer: "清理后，如果有很久没用的应用，会问你要不要退出它们。不会自动退出。") {
                SettingsRow(title: "多久没用算很久", symbol: "hourglass", color: .indigo) {
                    SettingsMenu(
                        title: "多久没用算很久",
                        selection: $settings.idleThreshold,
                        options: IdleThreshold.allCases,
                        label: \.label
                    )
                }
                SettingsRow(title: "提醒频率", symbol: "bell.badge.fill", color: .orange, showsDivider: false) {
                    SettingsMenu(
                        title: "提醒频率",
                        selection: $settings.idleReminderFrequency,
                        options: IdleReminderFrequency.allCases,
                        label: \.label
                    )
                }
            }
        }
    }

    private var showsSoundPicker: Bool {
        settings.soundEnabled && !settings.availableCleanSounds.isEmpty
    }

    private var titleColorFooter: String {
        if settings.titleColorMode == .followSystem {
            return "浅色外观用近黑，深色外观用白色，跟着系统换。"
        }
        return "系统是浅色时用上面选的颜色，深色时用下面选的颜色。"
    }
}

/// 一颗颜色圆点。选中的颜色存成不透明的红绿蓝。
private struct TitleColorWell: View {
    let title: String
    @Binding var color: TitleColor

    var body: some View {
        ColorPicker(title, selection: selection, supportsOpacity: false)
            .labelsHidden()
            .controlSize(.small)
            .fixedSize()
    }

    private var selection: Binding<Color> {
        Binding(
            get: {
                Color(red: color.red, green: color.green, blue: color.blue, opacity: 1)
            },
            set: { newColor in
                guard let converted = TitleColor(appKitColor: NSColor(newColor)) else { return }
                color = converted
            }
        )
    }
}

extension TitleColor {
    /// 从颜色选择器拿到的颜色换成红绿蓝。换不成就返回 nil，保留原来的颜色。
    init?(appKitColor: NSColor) {
        guard let rgb = appKitColor.usingColorSpace(NSColorSpace.sRGB) else { return nil }
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard rgb.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        self.init(red: Double(red), green: Double(green), blue: Double(blue))
    }
}

struct FocusSettingsPage: View {
    @ObservedObject var settings: SettingsModel

    var body: some View {
        SettingsPage {
            SettingsGroup(header: "时长", footer: "改了之后，下一次专注或休息开始时生效。") {
                SettingsRow(title: "专注", symbol: "timer", color: .orange) {
                    minutesMenu("专注", selection: $settings.focusMinutes, options: FocusDurationOptions.focusMinutes)
                }
                SettingsRow(title: "休息", symbol: "cup.and.saucer.fill", color: .mint) {
                    minutesMenu("休息", selection: $settings.shortBreakMinutes, options: FocusDurationOptions.shortBreakMinutes)
                }
                SettingsRow(title: "每 4 个专注后的长休息", symbol: "sofa.fill", color: .teal, showsDivider: false) {
                    minutesMenu(
                        "每 4 个专注后的长休息",
                        selection: $settings.longBreakMinutes,
                        options: FocusDurationOptions.longBreakMinutes
                    )
                }
            }

            SettingsGroup(
                header: "提醒",
                footer: "休息时只会盖一层玻璃，不会收起或关闭任何应用。正在用全屏应用或开了开会模式时，只用小时钟提醒。"
            ) {
                SettingsRow(title: "休息时", symbol: "rectangle.inset.filled", color: .purple) {
                    SettingsMenu(
                        title: "休息时",
                        selection: $settings.breakReminderStyle,
                        options: BreakReminderStyle.allCases,
                        label: \.label
                    )
                }
                SettingsRow(title: "专注时显示角落小时钟", symbol: "clock.fill", color: .blue, showsDivider: false) {
                    Toggle("专注时显示角落小时钟", isOn: $settings.showsFocusClock)
                        .toggleStyle(.switch)
                        .controlSize(.small)
                        .labelsHidden()
                }
            }
        }
    }

    private func minutesMenu(_ title: String, selection: Binding<Int>, options: [Int]) -> some View {
        SettingsMenu(title: title, selection: selection, options: options) { FocusDurationOptions.label(minutes: $0) }
    }
}

struct ShortcutSettingsPage: View {
    var body: some View {
        SettingsPage {
            SettingsGroup(footer: "点右边的框，再按下想用的组合键。按 ⌫ 清除。") {
                SettingsRow(title: "一键清理", symbol: "wand.and.stars", color: .blue) {
                    KeyboardShortcuts.Recorder(for: .cleanDesktop)
                }
                SettingsRow(title: "打开面板", symbol: "sparkles", color: .gray, showsDivider: false) {
                    KeyboardShortcuts.Recorder(for: .togglePanel)
                }
            }
        }
    }
}

struct SceneSettingsPage: View {
    @ObservedObject var scenes: SceneModel

    var body: some View {
        SettingsPage {
            SceneEditorView(scenes: scenes)
        }
    }
}
