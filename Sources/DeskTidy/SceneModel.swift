import Foundation
import DeskTidyCore

final class SceneModel: ObservableObject {
    private let store = SceneStore()

    var scenes: [WorkScene] { store.scenes }

    @Published var selectedID: String {
        didSet { store.select(sceneID: selectedID) }
    }

    init() {
        selectedID = store.selectedScene.id
    }
}
