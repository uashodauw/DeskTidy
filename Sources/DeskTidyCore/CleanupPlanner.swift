public enum CleanupPlanner {
    /// 一键清理时要隐藏的应用：除了当前在用的应用，其他全部。
    /// 已经被用户自己隐藏的应用不算，这样它们不会进入清理记录，恢复时也不会被放回来。
    public static func appsToHide(running: [RunningApp], current: RunningApp?) -> [RunningApp] {
        running.filter { !$0.isHidden && $0.bundleID != current?.bundleID }
    }
}
