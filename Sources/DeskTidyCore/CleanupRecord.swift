/// 清理记录：本应用亲手隐藏了哪些应用。用身份证号记录，应用重启后进程编号会变，身份证号不会。
public struct CleanupRecord: Equatable {
    public private(set) var hiddenBundleIDs: [String]

    public init(hiddenBundleIDs: [String] = []) {
        self.hiddenBundleIDs = hiddenBundleIDs
    }

    public var isEmpty: Bool { hiddenBundleIDs.isEmpty }

    /// 连续清理多次时累加，恢复时一次全部放回。
    public mutating func add(_ apps: [RunningApp]) {
        for app in apps where !hiddenBundleIDs.contains(app.bundleID) {
            hiddenBundleIDs.append(app.bundleID)
        }
    }

    /// 恢复时要放回的应用：只包括本应用亲手隐藏、并且现在仍然隐藏着的。
    public func appsToRestore(running: [RunningApp]) -> [RunningApp] {
        running.filter { $0.isHidden && hiddenBundleIDs.contains($0.bundleID) }
    }
}
