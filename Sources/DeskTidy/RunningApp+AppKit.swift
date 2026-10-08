import AppKit
import DeskTidyCore

extension RunningApp {
    /// 只接受 Dock 里有图标、并且有身份证号的普通应用。
    init?(_ app: NSRunningApplication) {
        guard app.activationPolicy == .regular, let bundleID = app.bundleIdentifier else { return nil }
        self.init(
            bundleID: bundleID,
            name: app.localizedName ?? bundleID,
            processID: app.processIdentifier,
            isHidden: app.isHidden
        )
    }
}
