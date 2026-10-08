import Foundation

/// 场景列表和"当前选中的场景"，都存在 UserDefaults 里，重启后还在。
public final class SceneStore {
    static let selectedSceneKey = "selectedSceneID"
    static let scenesKey = "scenes"
    /// 存成空字符串而不是删掉这一项：删掉会被当成"没选过"，又回到第一个场景。
    static let noSceneID = ""
    /// 以后改了场景的保存格式，就把这个数字加 1，并在 load 里处理旧格式，否则老用户的场景会被当成坏数据清掉。
    static let currentVersion = 1

    struct SavedScenes: Codable {
        let version: Int
        let scenes: [WorkScene]
    }

    private enum LoadResult {
        case missing
        case loaded([WorkScene], needsUpgrade: Bool)
        case unreadable
    }

    public private(set) var scenes: [WorkScene]
    /// 存的场景读不出来、已经换回默认场景时为 true，用来提示用户一次。
    public private(set) var recoveredFromCorruptData = false
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard, defaultScenes: [WorkScene] = DefaultScenes.all) {
        precondition(!defaultScenes.isEmpty, "至少要有一个场景")
        self.defaults = defaults
        switch Self.load(from: defaults) {
        case .missing:
            scenes = defaultScenes
        case let .loaded(saved, needsUpgrade):
            scenes = saved
            if needsUpgrade {
                save()
            }
        case .unreadable:
            scenes = defaultScenes
            recoveredFromCorruptData = true
            defaults.removeObject(forKey: Self.selectedSceneKey)
            save()
        }
    }

    /// nil 表示用户主动选了"无场景"。没选过、或者存的场景已经不存在时，用第一个场景。
    public var selectedScene: WorkScene? {
        let savedID = defaults.string(forKey: Self.selectedSceneKey)
        if savedID == Self.noSceneID {
            return nil
        }
        return scenes.first { $0.id == savedID } ?? scenes[0]
    }

    /// 当前要保留的应用。无场景时为空：清理时只保留当前在用的应用。
    public var keptBundleIDs: [String] {
        selectedScene?.keptBundleIDs ?? []
    }

    public func select(sceneID: String) {
        guard scenes.contains(where: { $0.id == sceneID }) else { return }
        defaults.set(sceneID, forKey: Self.selectedSceneKey)
    }

    public func selectNoScene() {
        defaults.set(Self.noSceneID, forKey: Self.selectedSceneKey)
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
        let saved = SavedScenes(version: Self.currentVersion, scenes: scenes)
        if let data = try? JSONEncoder().encode(saved) {
            defaults.set(data, forKey: Self.scenesKey)
        }
    }

    private static func load(from defaults: UserDefaults) -> LoadResult {
        guard defaults.object(forKey: scenesKey) != nil else { return .missing }
        guard let data = defaults.data(forKey: scenesKey) else { return .unreadable }
        let decoder = JSONDecoder()
        if let saved = try? decoder.decode(SavedScenes.self, from: data) {
            guard saved.version == currentVersion, !saved.scenes.isEmpty else { return .unreadable }
            return .loaded(saved.scenes, needsUpgrade: false)
        }
        // 版本 0：加版本号之前直接存的场景数组
        if let legacy = try? decoder.decode([WorkScene].self, from: data), !legacy.isEmpty {
            return .loaded(legacy, needsUpgrade: true)
        }
        return .unreadable
    }
}
