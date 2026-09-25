import AppKit
import SwiftUI

/// Fixed-size transparent canvas over the notch; the island animates inside it.
final class NotchPanel: NSPanel {
    private let state: IslandState
    private var geometry: NotchGeometry

    init(screen: NSScreen, state: IslandState) {
        self.state = state
        self.geometry = NotchGeometry(screen: screen)
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar + 1
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        isReleasedWhenClosed = false

        state.geometry = geometry
        let host = IslandHostingView(rootView: IslandView(state: state))
        host.state = state
        contentView = host
        applyFrame()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func relayout(on screen: NSScreen) {
        geometry = NotchGeometry(screen: screen)
        state.geometry = geometry
        applyFrame()
    }

    private func applyFrame() {
        let size = state.canvasSize
        let screenFrame = geometry.screen.frame
        let origin = CGPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height)
        setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
