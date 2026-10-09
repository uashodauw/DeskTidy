/// 哪些应用可以在"正在运行"列表里直接退出。
public enum QuitRules {
    /// 访达是系统的一部分：退出后会立刻自动重新打开，给用户一个退出按钮只会让人困惑。
    static let protectedBundleIDs: Set<String> = ["com.apple.finder"]

    public static func canQuitFromPanel(_ app: RunningApp) -> Bool {
        !protectedBundleIDs.contains(app.bundleID)
    }
}
