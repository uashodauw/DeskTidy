import Foundation
import DeskTidyCore

final class SceneModel: ObservableObject {
    private let store = SceneStore()

    @Published private(set) var scenes: [WorkScene]

    @Published var selectedID: String {
        didSet { store.select(sceneID: selectedID) }
    }

    var recoveredFromCorruptData: Bool { store.recoveredFromCorruptData }

    var selectedScene: WorkScene {
        scenes.first { $0.id == selectedID } ?? store.selectedScene
    }

    init() {
        scenes = store.scenes
        selectedID = store.selectedScene.id
    }

    func isKept(_ app: RunningApp) -> Bool {
        selectedScene.keptBundleIDs.contains(app.bundleID)
    }

    func setKept(_ app: RunningApp, _ kept: Bool) {
        store.setApp(app.bundleID, kept: kept, inSceneID: selectedID)
        scenes = store.scenes
    }
}
