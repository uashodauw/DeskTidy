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
}
