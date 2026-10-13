import Foundation

/// 插件打开后的一种底色，存成不透明的红绿蓝。
/// 浅色外观和深色外观各有一种。默认是设计好的两套；在圆盘上选过之后用自己的。
public struct TitleColor: Equatable {
    public var red: Double
    public var green: Double
    public var blue: Double

    /// 浅色外观：带一点蓝的白，字用深色才清楚。
    public static let lightAppearance = TitleColor(hex: "E7EEF6")!
    /// 深色外观：深蓝灰，字用浅色才清楚。
    public static let darkAppearance = TitleColor(hex: "1C2430")!

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

    /// 底色够深时，整块界面改用深色外观（浅色字）。
    public var isDarkBackground: Bool {
        relativeLuminance < 0.55
    }

    /// 色相 0...1、饱和度 0...1、明度 0...1。圆盘用色相和饱和度，滑杆用明度。
    public var hue: Double {
        let maxValue = max(red, green, blue)
        let delta = maxValue - min(red, green, blue)
        guard delta > 0.00001 else { return 0 }
        let sector: Double
        if maxValue == red {
            sector = (green - blue) / delta + (green < blue ? 6 : 0)
        } else if maxValue == green {
            sector = (blue - red) / delta + 2
        } else {
            sector = (red - green) / delta + 4
        }
        return sector / 6
    }

    public var saturation: Double {
        let maxValue = max(red, green, blue)
        guard maxValue > 0.00001 else { return 0 }
        return (maxValue - min(red, green, blue)) / maxValue
    }

    public var brightness: Double {
        max(red, green, blue)
    }

    public init(hue: Double, saturation: Double, brightness: Double) {
        let wrapped = hue - floor(hue)
        let sat = Self.unit(saturation)
        let value = Self.unit(brightness)
        let sector = Int(wrapped * 6) % 6
        let fraction = wrapped * 6 - Double(Int(wrapped * 6))
        let p = value * (1 - sat)
        let q = value * (1 - fraction * sat)
        let t = value * (1 - (1 - fraction) * sat)
        let (r, g, b): (Double, Double, Double)
        switch sector {
        case 0: (r, g, b) = (value, t, p)
        case 1: (r, g, b) = (q, value, p)
        case 2: (r, g, b) = (p, value, t)
        case 3: (r, g, b) = (p, q, value)
        case 4: (r, g, b) = (t, p, value)
        default: (r, g, b) = (value, p, q)
        }
        self.init(red: r, green: g, blue: b)
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

    private var relativeLuminance: Double {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }

    private static func unit(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }
}

/// 打开后的颜色怎么定：跟着系统外观用设计好的两套，或者用圆盘上选的两套。
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
