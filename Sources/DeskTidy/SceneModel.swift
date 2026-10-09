import Foundation
import DeskTidyCore

final class SceneModel: ObservableObject {
    private let store = SceneStore()

    @Published private(set) var scenes: [WorkScene]

    /// nil 表示无场景模式。
    @Published private(set) var selectedID: String? {
        didSet {
            if let selectedID {
                store.select(sceneID: selectedID)
            } else {
                store.selectNoScene()
            }
        }
    }

    var recoveredFromCorruptData: Bool { store.recoveredFromCorruptData }

    var selectedScene: WorkScene? {
        scenes.first { $0.id == selectedID }
    }

    var keptBundleIDs: [String] {
        selectedScene?.keptBundleIDs ?? []
    }

    init() {
        scenes = store.scenes
        selectedID = store.selectedScene?.id
    }

    /// 点未选中的场景就选中它；再点一次已选中的场景，就回到无场景模式。
    func toggle(_ scene: WorkScene) {
        selectedID = selectedID == scene.id ? nil : scene.id
    }

    func isKept(_ app: RunningApp) -> Bool {
        keptBundleIDs.contains(app.bundleID)
    }

    func setKept(_ app: RunningApp, _ kept: Bool) {
        guard let selectedID else { return }
        store.setApp(app.bundleID, kept: kept, inSceneID: selectedID)
        scenes = store.scenes
    }

    // MARK: - 自定义场景

    var canAddScene: Bool { store.canAddScene }
    var canDeleteScene: Bool { store.canDeleteScene }

    /// 新建后直接选中它：用户下一步就是去"正在运行"里勾要保留的应用。返回问题，成功时为 nil。
    func addScene(named name: String) -> SceneEditing.NameProblem? {
        if let problem = SceneEditing.problem(with: name, among: scenes) {
            return problem
        }
        guard let scene = store.addScene(named: name) else { return nil }
        scenes = store.scenes
        selectedID = scene.id
        return nil
    }

    func renameScene(_ scene: WorkScene, to name: String) -> SceneEditing.NameProblem? {
        if let problem = SceneEditing.problem(with: name, among: scenes, renamingID: scene.id) {
            return problem
        }
        store.renameScene(id: scene.id, to: name)
        scenes = store.scenes
        return nil
    }

    func deleteScene(_ scene: WorkScene) {
        guard store.deleteScene(id: scene.id) else { return }
        scenes = store.scenes
        if selectedID == scene.id {
            selectedID = nil
        }
    }
}
