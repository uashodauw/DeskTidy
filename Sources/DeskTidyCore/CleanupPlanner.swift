public enum CleanupPlanner {
    /// 一键清理时要隐藏的应用：当前在用的应用和场景里的应用保留，其他全部隐藏。
    /// 已经被用户自己隐藏的应用不算，这样它们不会进入清理记录，恢复时也不会被放回来。
    public static func appsToHide(
        running: [RunningApp],
        current: RunningApp?,
        keptBundleIDs: [String]
    ) -> [RunningApp] {
        let kept = Set(keptBundleIDs)
        return running.filter { app in
            !app.isHidden && app.bundleID != current?.bundleID && !kept.contains(app.bundleID)
        }
    }
}
