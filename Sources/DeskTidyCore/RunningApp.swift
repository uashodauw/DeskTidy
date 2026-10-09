import Foundation

/// 一个正在运行、带 Dock 图标的应用。用 bundleID（应用的"身份证号"）区分应用，不用名字。
public struct RunningApp: Equatable, Identifiable {
    public let bundleID: String
    public let name: String
    public let processID: Int32
    public let isHidden: Bool

    public var id: String { bundleID }

    public init(bundleID: String, name: String, processID: Int32, isHidden: Bool = false) {
        self.bundleID = bundleID
        self.name = name
        self.processID = processID
        self.isHidden = isHidden
    }
}

public enum RunningAppList {
    /// 去掉本应用自己、去掉同一个应用的重复项，并按名字排序。
    public static func make(from candidates: [RunningApp], excludingProcessID ownProcessID: Int32) -> [RunningApp] {
        var seen = Set<String>()
        let unique = candidates.filter { app in
            app.processID != ownProcessID && seen.insert(app.bundleID).inserted
        }
        return unique.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    /// 按"多久前用过"排序：正在用的排第一，越近用过越靠前；没有使用记录的放最后，按名字排。
    public static func sortedByRecentUse(
        _ apps: [RunningApp],
        currentBundleID: String?,
        lastUsed: (RunningApp) -> Date?
    ) -> [RunningApp] {
        let keyed = apps.map { (app: $0, used: lastUsed($0)) }
        return keyed.sorted { a, b in
            let aCurrent = a.app.bundleID == currentBundleID
            let bCurrent = b.app.bundleID == currentBundleID
            if aCurrent != bCurrent { return aCurrent }
            switch (a.used, b.used) {
            case let (x?, y?) where x != y:
                return x > y
            case (_?, nil):
                return true
            case (nil, _?):
                return false
            default:
                return a.app.name.localizedStandardCompare(b.app.name) == .orderedAscending
            }
        }.map(\.app)
    }
}
