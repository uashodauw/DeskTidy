import Foundation

/// 面板标题「DeskTidy」的一种颜色，存成不透明的红绿蓝。
/// 浅色外观和深色外观各有一种：默认浅色近黑、深色纯白，设置里可以换成别的。
public struct TitleColor: Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    /// 浅色外观上的标题：近黑，和系统正文一样深，笔画不透明。
    public static let lightAppearance = TitleColor(hex: "1D1D1F")!
    /// 深色外观上的标题：纯白。
    public static let darkAppearance = TitleColor(hex: "FFFFFF")!

    public init(red: Double, green: Double, blue: Double) {
        self.red = Self.unit(red)
        self.green = Self.unit(green)
        self.blue = Self.unit(blue)
    }

    /// 六位十六进制，可以带 #。认不出来就返回 nil。
    public init?(hex: String) {
        var text = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("#") {
            text.removeFirst()
        }
        guard text.count == 6, let value = Int(text, radix: 16), value >= 0 else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    public var hex: String {
        String(format: "%02X%02X%02X", channel(red), channel(green), channel(blue))
    }

    /// 跟随系统时用设计好的两种颜色；自定义时用用户为当前外观选的那一种。
    public static func resolved(
        mode: TitleColorMode,
        isDarkAppearance: Bool,
        customLight: TitleColor,
        customDark: TitleColor
    ) -> TitleColor {
        switch mode {
        case .followSystem:
            return isDarkAppearance ? .darkAppearance : .lightAppearance
        case .custom:
            return isDarkAppearance ? customDark : customLight
        }
    }

    private func channel(_ value: Double) -> Int {
        Int((value * 255).rounded())
    }

    private static func unit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// 标题颜色怎么定：跟着系统外观，或者用自己选的两种颜色。
public enum TitleColorMode: String, CaseIterable {
    case followSystem
    case custom

    public var label: String {
        switch self {
        case .followSystem: return "跟随系统"
        case .custom: return "自定义"
        }
    }
}
