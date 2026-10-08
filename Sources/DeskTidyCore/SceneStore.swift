import Foundation

/// 场景列表和"当前选中的场景"。选中的场景存在 UserDefaults 里，重启后还在。
public final class SceneStore {
    static let selectedSceneKey = "selectedSceneID"

    public let scenes: [WorkScene]
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard, scenes: [WorkScene] = DefaultScenes.all) {
        precondition(!scenes.isEmpty, "至少要有一个场景")
        self.defaults = defaults
        self.scenes = scenes
    }

    /// 没选过、或者存的场景已经不存在时，用第一个场景。
    public var selectedScene: WorkScene {
        let savedID = defaults.string(forKey: Self.selectedSceneKey)
        return scenes.first { $0.id == savedID } ?? scenes[0]
    }

    public func select(sceneID: String) {
        guard scenes.contains(where: { $0.id == sceneID }) else { return }
        defaults.set(sceneID, forKey: Self.selectedSceneKey)
    }
}
