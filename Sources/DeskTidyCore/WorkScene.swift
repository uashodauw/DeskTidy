/// 一个工作场景：一键清理时，场景里的应用会被保留。应用用身份证号（bundleID）记录。
public struct WorkScene: Codable, Equatable, Identifiable {
    public let id: String
    public var name: String
    public var keptBundleIDs: [String]

    public init(id: String, name: String, keptBundleIDs: [String]) {
        self.id = id
        self.name = name
        self.keptBundleIDs = keptBundleIDs
    }
}

public enum DefaultScenes {
    public static let chatGPT = "com.openai.chat"
    public static let claude = "com.anthropic.claudefordesktop"
    public static let feishu = "com.electron.lark"
    public static let figma = "com.figma.Desktop"
    public static let tencentMeeting = "com.tencent.meeting"
    public static let zoom = "us.zoom.xos"
    public static let browsers = [
        "com.apple.Safari",
        "com.google.Chrome",
        "company.thebrowser.Browser",
        "com.microsoft.edgemac"
    ]

    public static let all: [WorkScene] = [
        WorkScene(id: "ai-work", name: "AI 工作", keptBundleIDs: [chatGPT, claude, feishu] + browsers),
        WorkScene(id: "design", name: "做设计", keptBundleIDs: [figma, chatGPT, feishu] + browsers),
        WorkScene(id: "meeting", name: "开会", keptBundleIDs: [feishu, tencentMeeting, zoom])
    ]
}
