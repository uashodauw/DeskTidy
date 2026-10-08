/// 记住用户最后使用的应用。本应用自己被激活时（比如点开面板）不算。
public struct FrontmostAppTracker {
    public let ownProcessID: Int32
    public private(set) var current: RunningApp?

    public init(ownProcessID: Int32, initial: RunningApp? = nil) {
        self.ownProcessID = ownProcessID
        if initial?.processID != ownProcessID {
            current = initial
        }
    }

    public mutating func appDidActivate(_ app: RunningApp) {
        guard app.processID != ownProcessID else { return }
        current = app
    }

    public mutating func appDidTerminate(processID: Int32) {
        if current?.processID == processID {
            current = nil
        }
    }
}
