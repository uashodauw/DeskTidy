import SwiftUI
import DeskTidyCore

@main
struct DeskTidyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra(AppInfo.displayName, systemImage: "sparkles") {
            PanelView()
        }
        .menuBarExtraStyle(.window)
    }
}
