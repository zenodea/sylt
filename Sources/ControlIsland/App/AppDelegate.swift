import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: NotchPanel?
    private let state = IslandState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let panel = NotchPanel(screen: screen, state: state)
        panel.orderFrontRegardless()
        self.panel = panel
        state.start()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, let screen = NotchGeometry.preferredScreen() else { return }
            self.panel?.relayout(on: screen)
        }
    }
}
