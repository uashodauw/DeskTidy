import Foundation

/// 自定义场景的规则：名字怎么算合格、最多几个场景。
public enum SceneEditing {
    /// 面板顶部一行放 3 个按钮，最多两行
    public static let maxScenes = 6
    /// 名字太长，按钮上显示不下
    public static let maxNameLength = 8

    public enum NameProblem: Equatable {
        case empty
        case tooLong
        case duplicate

        public var message: String {
            switch self {
            case .empty: return "名字不能为空"
            case .tooLong: return "名字最多 \(SceneEditing.maxNameLength) 个字"
            case .duplicate: return "已经有同名的场景了"
            }
        }
    }

    /// 去掉首尾空格后检查名字。改名时传 renamingID，自己原来的名字不算重名。
    public static func problem(
        with name: String,
        among scenes: [WorkScene],
        renamingID: String? = nil
    ) -> NameProblem? {
        let trimmed = cleaned(name)
        if trimmed.isEmpty { return .empty }
        if trimmed.count > maxNameLength { return .tooLong }
        if scenes.contains(where: { $0.id != renamingID && $0.name == trimmed }) { return .duplicate }
        return nil
    }

    public static func cleaned(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
