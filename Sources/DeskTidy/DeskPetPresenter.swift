import AppKit
import Combine
import KeyboardShortcuts
import SwiftUI
import DeskTidyCore

/// 一直待在桌面右下角的小猫，让用户随时记得 DeskTidy 在。
///
/// 绝不妨碍正常使用：
/// - 整个窗口不接收鼠标，点击直接落到下面的窗口上，不可能点错；
/// - 鼠标靠近时变得几乎透明，不挡住下面的内容；
/// - 共享屏幕、截图时不出现；全屏应用里不出现；不进 ⌘Tab 和调度中心。
final class DeskPetPresenter {
    static let petSize: CGFloat = 60
    private static let windowSize = NSSize(width: 230, height: 150)
    private static let screenInset: CGFloat = 12
    private static let fadeReach: CGFloat = 20

    private let model: DeskPetModel
    private var panel: NSPanel?
    private var mouseMonitors: [Any] = []
    private var screenObserver: NSObjectProtocol?

    init(runningApps: RunningAppsModel) {
        model = DeskPetModel(runningApps: runningApps)
        model.dizzyHint = { "有点乱了…按 \(Self.shortcutText(.cleanDesktop)) 我帮你收拾一下？" }
    }

    var isShown: Bool { panel?.isVisible == true }

    func show() {
        guard !isShown, PetArt.isAvailable else { return }
        let panel = self.panel ?? makePanel()
        self.panel = panel
        place(panel)
        panel.orderFrontRegardless()
        installMonitors()
    }

    func hide() {
        panel?.orderOut(nil)
        removeMonitors()
    }

    func greet() {
        model.say("嗨，我是 DeskTidy 的小猫。桌面乱了，按 \(Self.shortcutText(.cleanDesktop)) 叫我整理～", for: 7)
    }

    func celebrate() {
        model.celebrate()
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: Self.windowSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.sharingType = .none
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        let host = NSHostingView(rootView: DeskPetView(model: model))
        host.sizingOptions = []
        panel.contentView = host

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self, weak panel] _ in
            if let panel { self?.place(panel) }
        }
        return panel
    }

    /// 主屏幕（有菜单栏的那块）右下角、程序坞上方
    private func place(_ panel: NSPanel) {
        guard let screen = NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        panel.setFrame(NSRect(
            x: visible.maxX - Self.windowSize.width - Self.screenInset,
            y: visible.minY + Self.screenInset,
            width: Self.windowSize.width,
            height: Self.windowSize.height
        ), display: true)
    }

    // MARK: - 鼠标靠近时让开

    private func installMonitors() {
        guard mouseMonitors.isEmpty else { return }
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        if let global = NSEvent.addGlobalMonitorForEvents(matching: events, handler: { [weak self] _ in
            self?.updateFade()
        }) {
            mouseMonitors.append(global)
        }
        if let local = NSEvent.addLocalMonitorForEvents(matching: events, handler: { [weak self] event in
            self?.updateFade()
            return event
        }) {
            mouseMonitors.append(local)
        }
    }

    private func removeMonitors() {
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors.removeAll()
    }

    private func updateFade() {
        guard let frame = panel?.frame else { return }
        let occupied: NSRect
        if model.bubble != nil {
            occupied = frame
        } else {
            occupied = NSRect(
                x: frame.maxX - Self.petSize, y: frame.minY, width: Self.petSize, height: Self.petSize
            )
        }
        let near = occupied.insetBy(dx: -Self.fadeReach, dy: -Self.fadeReach).contains(NSEvent.mouseLocation)
        if near != model.isFaded {
            withAnimation(.easeOut(duration: 0.18)) { model.isFaded = near }
        }
    }

    private static func shortcutText(_ name: KeyboardShortcuts.Name) -> String {
        KeyboardShortcuts.getShortcut(for: name)?.description ?? "面板里的「一键清理」"
    }
}

// MARK: - 状态

final class DeskPetModel: ObservableObject {
    @Published private(set) var mood: PetMood = .calm
    @Published private(set) var bubble: String?
    @Published private(set) var hops = 0
    @Published var isFaded = false

    private var lastDizzyHint: Date?
    private var bubbleGeneration = 0
    private var subscription: AnyCancellable?

    /// 提示里要显示用户当前设置的快捷键，所以每次用的时候再生成
    var dizzyHint: (() -> String)?

    init(runningApps: RunningAppsModel) {
        subscription = runningApps.$apps
            .map { apps in PetMood.from(visibleAppCount: apps.filter { !$0.isHidden }.count) }
            .removeDuplicates()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mood in self?.moodChanged(to: mood) }
    }

    func say(_ text: String, for seconds: TimeInterval) {
        bubbleGeneration += 1
        let current = bubbleGeneration
        withAnimation(TidyMotion.layout) { bubble = text }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
            guard let self, self.bubbleGeneration == current else { return }
            withAnimation(.easeOut(duration: 0.25)) { self.bubble = nil }
        }
    }

    func celebrate() {
        hops += 1
    }

    private func moodChanged(to newMood: PetMood) {
        let oldMood = mood
        withAnimation(TidyMotion.layout) { mood = newMood }
        if newMood == .happy && oldMood != .happy {
            hops += 1
        }
        if newMood == .dizzy, oldMood != .dizzy,
           PetHintPolicy.shouldShowDizzyHint(lastShown: lastDizzyHint, now: Date()),
           let hint = dizzyHint?() {
            lastDizzyHint = Date()
            say(hint, for: 6)
        }
    }
}

// MARK: - 画面

/// 小猫的图层（Packaging/Pet，由 scripts/make-pet.py 画出）。打包后在 Contents/Resources/Pet 里；
/// 开发时用 swift run 运行，就直接读项目里的原图。
enum PetArt {
    static let tail = load("tail")
    static let body = load("body")
    static let faceCalm = load("face-calm")
    static let faceBlink = load("face-blink")
    static let faceHappy = load("face-happy")
    static let faceDizzy = load("face-dizzy")

    static var isAvailable: Bool {
        [tail, body, faceCalm, faceBlink, faceHappy, faceDizzy].allSatisfy { $0 != nil }
    }

    private static func load(_ name: String) -> NSImage? {
        let bundled = Bundle.main.url(forResource: name, withExtension: "png", subdirectory: "Pet")
        let source = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Packaging/Pet/\(name).png")
        let url = bundled ?? (FileManager.default.fileExists(atPath: source.path) ? source : nil)
        guard let url, let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: DeskPetPresenter.petSize, height: DeskPetPresenter.petSize)
        return image
    }
}

private struct DeskPetView: View {
    @ObservedObject var model: DeskPetModel

    var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            if let text = model.bubble {
                Text(text)
                    .font(.callout)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .tidyGlass(in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .frame(maxWidth: 210, alignment: .trailing)
                    .transition(.scale(scale: 0.85, anchor: .bottomTrailing).combined(with: .opacity))
            }
            PetSprite(mood: model.mood, hops: model.hops)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .opacity(model.isFaded ? 0.12 : 1)
    }
}

private struct PetSprite: View {
    let mood: PetMood
    let hops: Int

    @State private var inhale = false
    @State private var blinking = false
    @State private var hopping = false

    private static let breathDuration: Double = 1.8
    /// 尾巴根部在原图里的位置（64 格设计稿里的 44, 54）
    private static let tailAnchor = UnitPoint(x: 44.0 / 64, y: 54.0 / 64)

    var body: some View {
        ZStack {
            layer(PetArt.tail)
                .rotationEffect(.degrees(tailAngle), anchor: Self.tailAnchor)
            layer(PetArt.body)
            layer(face)
        }
        .frame(width: DeskPetPresenter.petSize, height: DeskPetPresenter.petSize)
        .scaleEffect(x: inhale ? 1.015 : 1, y: inhale ? 0.975 : 1, anchor: .bottom)
        .rotationEffect(.degrees(mood == .dizzy ? (inhale ? 3 : -3) : 0), anchor: .bottom)
        .offset(y: hopping ? -8 : 0)
        .task { await breathe() }
        .task { await blink() }
        .onChange(of: hops) { _ in hop() }
    }

    private var tailAngle: Double {
        switch mood {
        case .happy: return inhale ? 10 : -6
        case .calm: return inhale ? 4 : -2
        case .dizzy: return inhale ? -2 : -6
        }
    }

    private var face: NSImage? {
        switch mood {
        case .happy: return PetArt.faceHappy
        case .calm: return blinking ? PetArt.faceBlink : PetArt.faceCalm
        case .dizzy: return PetArt.faceDizzy
        }
    }

    @ViewBuilder
    private func layer(_ image: NSImage?) -> some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .interpolation(.high)
        }
    }

    /// 隔一会儿才切换一次状态，中间交给系统做补间：一直开着也几乎不占电脑资源
    private func breathe() async {
        while !Task.isCancelled {
            withAnimation(.easeInOut(duration: Self.breathDuration)) { inhale.toggle() }
            try? await Task.sleep(nanoseconds: UInt64(Self.breathDuration * 1_000_000_000))
        }
    }

    private func blink() async {
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(Double.random(in: 2.5...6) * 1_000_000_000))
            blinking = true
            try? await Task.sleep(nanoseconds: 130_000_000)
            blinking = false
        }
    }

    private func hop() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.5)) { hopping = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.55)) { hopping = false }
        }
    }
}
