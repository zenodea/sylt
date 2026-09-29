import AppKit
import Combine
import SwiftUI

/// Fixed-size transparent canvas over the notch; the island animates inside it.
/// The panel only takes the mouse while the cursor is over the island, so the
/// rest of the canvas stays click-through even inside the SkyLight space.
final class NotchPanel: NSPanel {
    private let state: IslandState
    private var geometry: NotchGeometry
    private var cancellables = Set<AnyCancellable>()
    private var mouseMonitors: [Any] = []

    init(screen: NSScreen, state: IslandState, openSettings: @escaping () -> Void) {
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
        level = .screenSaver
        canBecomeVisibleWithoutLogin = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        hidesOnDeactivate = false
        acceptsMouseMovedEvents = true
        ignoresMouseEvents = true
        isReleasedWhenClosed = false

        state.apply(geometry)
        let host = IslandHostingView(rootView: IslandView(state: state, openSettings: openSettings))
        host.state = state
        contentView = host
        applyFrame()
        SkyLight.pinAboveLockScreen(self)
        trackCursor()
    }

    deinit {
        mouseMonitors.forEach(NSEvent.removeMonitor)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    func relayout(on screen: NSScreen) {
        geometry = NotchGeometry(screen: screen)
        state.apply(geometry)
        applyFrame()
    }

    private func trackCursor() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        mouseMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] _ in self?.routeMouse() } as Any,
            NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
                self?.routeMouse()
                return event
            } as Any,
        ]
        state.lock.$isLocked
            .sink { [weak self] _ in self?.routeMouse() }
            .store(in: &cancellables)
    }

    private func routeMouse() {
        let location = NSEvent.mouseLocation
        state.cursorMoved(to: CGPoint(x: location.x - frame.minX, y: frame.maxY - location.y))
        ignoresMouseEvents = state.lock.isLocked || !state.isHovering
    }

    private func applyFrame() {
        let size = state.canvasSize
        let screenFrame = geometry.screen.frame
        let origin = CGPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height)
        setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
