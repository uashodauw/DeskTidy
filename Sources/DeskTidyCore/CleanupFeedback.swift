/// 清理完成后浮窗里显示的内容。
public struct CleanupFeedback: Equatable {
    public let message: String
    public let systemImage: String

    public init(hiddenCount: Int) {
        if hiddenCount > 0 {
            message = "已收起 \(hiddenCount) 个应用"
            systemImage = "sparkles"
        } else {
            message = "桌面已经很清爽了"
            systemImage = "checkmark.circle"
        }
    }
}
