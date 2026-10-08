import Foundation

/// 用 `swift run` 启动时，设置存在名为 "DeskTidy" 的位置；打包成 .app 后，存在应用自己的 bundleID 下。
/// 第一次以 .app 启动时，把旧位置的设置（场景、提示音、快捷键等）搬过来，只搬一次。
public enum LegacySettingsMigration {
    public static let legacyDomain = "DeskTidy"
    static let doneKey = "migratedFromCommandLineSettings"

    /// 返回这次是否真的搬了设置。新位置已有的设置不会被旧设置覆盖。
    @discardableResult
    public static func migrate(legacy: [String: Any]?, into defaults: UserDefaults) -> Bool {
        guard !defaults.bool(forKey: doneKey) else { return false }
        defaults.set(true, forKey: doneKey)
        guard let legacy, !legacy.isEmpty else { return false }
        for (key, value) in legacy where defaults.object(forKey: key) == nil {
            defaults.set(value, forKey: key)
        }
        return true
    }
}
