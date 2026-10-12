import SwiftUI
import DeskTidyCore

/// 设置窗口"场景"页：新建、改名、删除。要保留哪些应用，还是在面板的"正在运行"里打勾。
/// 样子和 iPhone"设置"里可编辑的列表一样：一组卡片，每行一个名字，最后一行新建。
struct SceneEditorView: View {
    @ObservedObject var scenes: SceneModel

    @State private var newName = ""
    @State private var problem: String?
    /// 点了删除、等第二次确认的场景。删掉会连同它的保留名单一起丢，所以要点两次
    @State private var confirmingDeleteID: String?

    private let confirmTimeout: TimeInterval = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsGroup(header: "我的场景", footer: "点名字可以直接改。删除要点两次。") {
                ForEach(Array(scenes.scenes.enumerated()), id: \.element.id) { index, scene in
                    SceneNameRow(
                        scene: scene,
                        canDelete: scenes.canDeleteScene,
                        isConfirmingDelete: confirmingDeleteID == scene.id,
                        showsDivider: index < scenes.scenes.count - 1,
                        onRename: { name in
                            let result = scenes.renameScene(scene, to: name)
                            show(result)
                            return result == nil
                        },
                        onDelete: { requestDelete(scene) }
                    )
                }
            }

            SettingsGroup(header: "新建场景", footer: hint, footerColor: problem == nil ? nil : Color.red) {
                SettingsRow(title: "", symbol: "plus", color: .green, showsDivider: false) {
                    HStack(spacing: 8) {
                        TextField("新场景名字", text: $newName)
                            .textFieldStyle(.plain)
                            .onSubmit(add)
                            .disabled(!scenes.canAddScene)
                        Button("添加", action: add)
                            .buttonStyle(TidyButtonStyle())
                            .fixedSize()
                            .disabled(!scenes.canAddScene || SceneEditing.cleaned(newName).isEmpty)
                    }
                }
            }
        }
    }

    private var hint: String {
        if let problem { return problem }
        if !scenes.canAddScene { return "最多 \(SceneEditing.maxScenes) 个场景，删掉一个才能再新建。" }
        return "新建后会自动选中，再到面板的「正在运行」里打勾要保留的应用。"
    }

    private func add() {
        let result = scenes.addScene(named: newName)
        show(result)
        if result == nil {
            withAnimation(TidyMotion.layout) { newName = "" }
        }
    }

    private func show(_ result: SceneEditing.NameProblem?) {
        withAnimation(TidyMotion.color) { problem = result?.message }
    }

    private func requestDelete(_ scene: WorkScene) {
        if confirmingDeleteID == scene.id {
            withAnimation(TidyMotion.layout) {
                confirmingDeleteID = nil
                scenes.deleteScene(scene)
            }
            return
        }
        withAnimation(TidyMotion.color) { confirmingDeleteID = scene.id }
        DispatchQueue.main.asyncAfter(deadline: .now() + confirmTimeout) {
            guard confirmingDeleteID == scene.id else { return }
            withAnimation(TidyMotion.color) { confirmingDeleteID = nil }
        }
    }
}

private struct SceneNameRow: View {
    let scene: WorkScene
    let canDelete: Bool
    let isConfirmingDelete: Bool
    let showsDivider: Bool
    /// 返回 false 表示名字不合格，输入框恢复原名
    let onRename: (String) -> Bool
    let onDelete: () -> Void

    @State private var draft: String
    @FocusState private var isFocused: Bool

    init(
        scene: WorkScene,
        canDelete: Bool,
        isConfirmingDelete: Bool,
        showsDivider: Bool,
        onRename: @escaping (String) -> Bool,
        onDelete: @escaping () -> Void
    ) {
        self.scene = scene
        self.canDelete = canDelete
        self.isConfirmingDelete = isConfirmingDelete
        self.showsDivider = showsDivider
        self.onRename = onRename
        self.onDelete = onDelete
        _draft = State(initialValue: scene.name)
    }

    var body: some View {
        SettingsRow(title: "", symbol: "square.stack.3d.up.fill", color: .blue, showsDivider: showsDivider) {
            HStack(spacing: 8) {
                TextField("场景名字", text: $draft)
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .onSubmit(commit)
                    .onChange(of: isFocused) { focused in
                        if !focused { commit() }
                    }
                    .onChange(of: scene.name) { name in
                        draft = name
                    }

                if canDelete {
                    Button(action: onDelete) {
                        if isConfirmingDelete {
                            Text("删除")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(Color.red)
                        } else {
                            Image(systemName: "trash")
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 32, alignment: .trailing)
                    .help(isConfirmingDelete ? "再点一次删除「\(scene.name)」" : "删除这个场景")
                }
            }
        }
    }

    private func commit() {
        guard SceneEditing.cleaned(draft) != scene.name else {
            draft = scene.name
            return
        }
        if !onRename(draft) {
            draft = scene.name
        }
    }
}
