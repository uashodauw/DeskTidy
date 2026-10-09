import Foundation

/// 清理提示音：只用 Mac 系统里本来就有的苹果原生音效，直接播放用户电脑上的文件。
/// 不能把 iOS 的音效文件打包进应用：那是苹果的版权素材。
public enum CleanSound: String, CaseIterable, Identifiable {
    case mailSent
    case glass
    case tink
    case pop
    case poof

    public static let defaultValue = CleanSound.mailSent

    public var id: String { rawValue }

    public var label: String {
        switch self {
        case .mailSent: return "嗖（iPhone 发送邮件）"
        case .glass: return "叮（Glass）"
        case .tink: return "轻点（Tink）"
        case .pop: return "啵（Pop）"
        case .poof: return "噗（移出程序坞）"
        }
    }

    /// 同一个声音在不同版本的 macOS 上放的位置可能不同，按顺序找第一个存在的。
    public var candidatePaths: [String] {
        switch self {
        case .mailSent:
            return [
                "/System/Applications/Mail.app/Contents/Resources/Mail Sent.aiff",
                "/Applications/Mail.app/Contents/Resources/Mail Sent.aiff"
            ]
        case .glass:
            return ["/System/Library/Sounds/Glass.aiff"]
        case .tink:
            return ["/System/Library/Sounds/Tink.aiff"]
        case .pop:
            return ["/System/Library/Sounds/Pop.aiff"]
        case .poof:
            return ["/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/dock/poof item off dock.aif"]
        }
    }

    public func path(fileExists: (String) -> Bool) -> String? {
        candidatePaths.first(where: fileExists)
    }

    /// 这台电脑上真的找得到文件的声音，列表里只显示这些。
    public static func available(fileExists: (String) -> Bool) -> [CleanSound] {
        allCases.filter { $0.path(fileExists: fileExists) != nil }
    }

    /// 用户选的声音在这台电脑上找不到时，换成第一个找得到的。
    public static func resolve(_ preferred: CleanSound, fileExists: (String) -> Bool) -> CleanSound? {
        preferred.path(fileExists: fileExists) != nil ? preferred : available(fileExists: fileExists).first
    }
}
