/// "很久没用"列表里用户勾选了哪些应用。默认一个都不勾：退出应用必须由用户自己决定。
public struct QuitSelection: Equatable {
    public private(set) var selectedBundleIDs: Set<String> = []

    public init() {}

    public var isEmpty: Bool { selectedBundleIDs.isEmpty }

    public func isSelected(_ app: RunningApp) -> Bool {
        selectedBundleIDs.contains(app.bundleID)
    }

    public mutating func setSelected(_ app: RunningApp, _ selected: Bool) {
        if selected {
            selectedBundleIDs.insert(app.bundleID)
        } else {
            selectedBundleIDs.remove(app.bundleID)
        }
    }

    /// 只退出列表里还在、而且被勾选的应用。
    public func appsToQuit(from apps: [RunningApp]) -> [RunningApp] {
        apps.filter(isSelected)
    }
}
