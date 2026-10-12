import AppKit
import SwiftUI
import DeskTidyCore

final class RunningAppsModel: ObservableObject {
    @Published private(set) var apps: [RunningApp] = []

    /// 面板每次重画都要图标；每次都向系统取原图（很大）会让面板发卡，所以缩小后存起来。
    private var iconCache: [String: NSImage] = [:]
    private let iconSize = NSSize(width: 36, height: 36)
    private var observers: [NSObjectProtocol] = []

    init() {
        // 应用打开、退出、被收起或恢复时自动更新列表：在面板里退出应用后那一行要自己消失
        let center = NSWorkspace.shared.notificationCenter
        let names = [
            NSWorkspace.didLaunchApplicationNotification,
            NSWorkspace.didTerminateApplicationNotification,
            NSWorkspace.didHideApplicationNotification,
            NSWorkspace.didUnhideApplicationNotification
        ]
        for name in names {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                withAnimation(TidyMotion.layout) { self?.refresh() }
            })
        }
    }

    deinit {
        observers.forEach { NSWorkspace.shared.notificationCenter.removeObserver($0) }
    }

    func refresh() {
        let candidates = NSWorkspace.shared.runningApplications.compactMap { RunningApp($0) }
        apps = RunningAppList.make(from: candidates, excludingProcessID: ProcessInfo.processInfo.processIdentifier)
        let runningIDs = Set(apps.map(\.bundleID))
        iconCache = iconCache.filter { runningIDs.contains($0.key) }
    }

    func icon(for app: RunningApp) -> NSImage? {
        if let cached = iconCache[app.bundleID] {
            return cached
        }
        guard let original = NSRunningApplication(processIdentifier: app.processID)?.icon,
              let small = Self.rasterize(original, to: iconSize) else { return nil }
        iconCache[app.bundleID] = small
        return small
    }

    /// 只画一次，存成固定像素的位图。不能用 NSImage(size:flipped:drawingHandler:)：
    /// 它每次显示都会重新把原图（1024 像素）缩小画一遍，列表一滚动就每行每帧都在画，非常卡。
    private static func rasterize(_ image: NSImage, to size: NSSize) -> NSImage? {
        let scale: CGFloat = 2
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(size.width * scale),
            pixelsHigh: Int(size.height * scale),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0
        ) else { return nil }
        bitmap.size = size
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size))
        NSGraphicsContext.restoreGraphicsState()
        let result = NSImage(size: size)
        result.addRepresentation(bitmap)
        return result
    }
}
