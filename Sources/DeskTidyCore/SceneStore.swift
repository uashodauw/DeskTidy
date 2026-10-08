import Foundation

/// 场景列表和"当前选中的场景"，都存在 UserDefaults 里，重启后还在。
public final class SceneStore {
    static let selectedSceneKey = "selectedSceneID"
    static let scenesKey = "scenes"

    public private(set) var scenes: [WorkScene]
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard, defaultScenes: [WorkScene] = DefaultScenes.all) {
        precondition(!defaultScenes.isEmpty, "至少要有一个场景")
        self.defaults = defaults
        scenes = Self.loadScenes(from: defaults) ?? defaultScenes
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

    /// 把某个应用加进场景的保留名单，或者从名单里去掉。改完立刻保存。
    public func setApp(_ bundleID: String, kept: Bool, inSceneID sceneID: String) {
        guard let index = scenes.firstIndex(where: { $0.id == sceneID }) else { return }
        var ids = scenes[index].keptBundleIDs
        ids.removeAll { $0 == bundleID }
        if kept {
            ids.append(bundleID)
        }
        scenes[index].keptBundleIDs = ids
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(scenes) {
            defaults.set(data, forKey: Self.scenesKey)
        }
    }

    private static func loadScenes(from defaults: UserDefaults) -> [WorkScene]? {
        guard let data = defaults.data(forKey: scenesKey),
              let scenes = try? JSONDecoder().decode([WorkScene].self, from: data),
              !scenes.isEmpty
        else { return nil }
        return scenes
    }
}
