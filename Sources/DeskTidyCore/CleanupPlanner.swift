public enum CleanupPlanner {
    /// 一键清理时要隐藏的应用：除了当前在用的应用，其他全部。
    public static func appsToHide(running: [RunningApp], current: RunningApp?) -> [RunningApp] {
        running.filter { $0.bundleID != current?.bundleID }
    }
}
