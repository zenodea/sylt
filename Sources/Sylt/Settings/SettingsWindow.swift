import AppKit
import SwiftUI

@MainActor
final class SettingsWindow {
    private let window: NSWindow

    init(preferences: Preferences, mediaKeys: MediaKeyInterceptor, plugins: PluginRegistry) {
        window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Sylt"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbarStyle = .unified
        window.isReleasedWhenClosed = false
        let controller = NSHostingController(rootView: SettingsView(preferences: preferences, mediaKeys: mediaKeys, plugins: plugins))
        window.contentViewController = controller
        window.setContentSize(NSSize(width: 920, height: 680))
        window.center()
        window.setFrameAutosaveName("Settings")
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}
