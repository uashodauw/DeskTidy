import AppKit
import DeskTidyCore

/// 计时中菜单栏上的图标：一个慢慢走满的小圆环，和星星一样大。
/// 不显示数字：数字会让图标变宽，菜单栏放不下时更容易被系统藏起来。
/// 做成"模板图"：系统会自动把它染成菜单栏的颜色，浅色、深色菜单栏都看得清。
enum FocusStatusIcon {
    private static let size = NSSize(width: 18, height: 18)

    static func image(for timer: FocusTimer, now: Date) -> NSImage {
        let progress = timer.progress(now: now)
        let isPaused = timer.isPaused
        let isBreak = timer.phase?.isBreak == true
        let image = NSImage(size: size, flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let radius: CGFloat = 7

            let track = NSBezierPath()
            track.appendArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 360)
            track.lineWidth = 1.5
            NSColor.black.withAlphaComponent(0.3).setStroke()
            track.stroke()

            if progress > 0 {
                let arc = NSBezierPath()
                arc.appendArc(withCenter: center, radius: radius, startAngle: 90, endAngle: 90 - 360 * progress, clockwise: true)
                arc.lineWidth = 2
                arc.lineCapStyle = .round
                NSColor.black.setStroke()
                arc.stroke()
            }

            NSColor.black.setFill()
            if isPaused {
                for dx in [-1.6, 1.6] as [CGFloat] {
                    NSBezierPath(
                        roundedRect: NSRect(x: center.x + dx - 0.75, y: center.y - 2.5, width: 1.5, height: 5),
                        xRadius: 0.75, yRadius: 0.75
                    ).fill()
                }
            } else if isBreak {
                NSBezierPath(ovalIn: NSRect(x: center.x - 2, y: center.y - 2, width: 4, height: 4)).fill()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = FocusStatusIcon.spokenText(for: timer, now: now)
        return image
    }

    static func spokenText(for timer: FocusTimer, now: Date) -> String {
        let remaining = FocusClockText.format(timer.remaining(now: now))
        switch timer.state {
        case .idle: return AppInfo.displayName
        case .running(let phase, _): return phase.isBreak ? "休息中，还剩 \(remaining)" : "专注中，还剩 \(remaining)"
        case .paused: return "已暂停，还剩 \(remaining)"
        case .finished(let phase, _): return phase.isBreak ? "休息结束" : "专注完成，该休息了"
        }
    }
}
