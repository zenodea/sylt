import AppKit
import Combine
import SwiftUI

/// Fixed-size transparent canvas over the notch; the island animates inside it.
/// The panel only takes the mouse while the cursor is over the island, so the
/// rest of the canvas stays click-through even inside the SkyLight space.
final class NotchPanel: NSPanel {
    private let state: IslandState
    private let host: IslandHostingView
    private var geometry: NotchGeometry
    private lazy var pointer = PointerCapture(state: state, panel: self)
    private var mouseMonitors: [Any] = []
    private var cancellables = Set<AnyCancellable>()
    private var lastMode = IslandMode.closed
    /// How far under the notch a free pointer is put when the island opens.
    private static let homeDepth: CGFloat = 16

    init(screen: NSScreen, state: IslandState, openSettings: @escaping () -> Void) {
        self.state = state
        self.geometry = NotchGeometry(screen: screen)
        host = IslandHostingView(rootView: IslandView(state: state, openSettings: openSettings))
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
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

    /// Only a real change of screen or notch moves anything; the menu bar sliding in and
    /// out also fires a screen change and must not.
    var isMeasured: Bool { geometry.isMeasured }

    func relayout(on screen: NSScreen) {
        let next = NotchGeometry(screen: screen)
        if next != geometry {
            geometry = next
            state.apply(geometry)
        }
        applyFrame()
    }

    /// The panel must sit centred on the notch screen's top edge. Display changes at
    /// login, wake and space switches can leave it elsewhere; this puts it back.
    func ensurePlacement() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        if frame != Self.frame(on: screen, size: state.canvasSize) || geometry.screen != screen {
            relayout(on: screen)
            SkyLight.pinAboveLockScreen(self)
            orderFrontRegardless()
        }
    }

    /// Where the pointer is handed back when the island is open: centred just under the
    /// notch, inside the panel, so it never lands outside and closes it again.
    var expandedHome: CGPoint {
        screenPoint(of: CGPoint(x: state.canvasSize.width / 2, y: state.notchHeight + Self.homeDepth))
    }

    /// The middle of the island, a touch below the notch's centre line.
    var islandCentre: CGPoint {
        screenPoint(of: CGPoint(x: state.canvasSize.width / 2 + state.islandFrame.centerOffset, y: state.notchHeight / 2 + 2))
    }

    /// Hover follows the free pointer; the panel is click-through unless it's over the island.
    func followPointer() {
        state.cursorMoved(to: canvasPoint(of: NSEvent.mouseLocation))
        ignoresMouseEvents = state.lock.isLocked || !state.isHovering
    }

    /// Canvas point (top-left origin) to Cocoa screen coordinates, and back.
    func screenPoint(of point: CGPoint) -> CGPoint {
        CGPoint(x: frame.minX + point.x, y: frame.maxY - point.y)
    }

    func canvasPoint(of point: CGPoint) -> CGPoint {
        CGPoint(x: point.x - frame.minX, y: frame.maxY - point.y)
    }

    private func trackCursor() {
        let events: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .leftMouseDown, .leftMouseUp]
        mouseMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in self?.routeMouse(event) } as Any,
            NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
                self?.routeMouse(event)
                return event
            } as Any,
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, state.isHovering || pointer.isCaptured else { return event }
                return host.handleScroll(event) ? nil : event
            } as Any,
        ]
        state.lock.$isLocked
            .combineLatest(state.$mode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, mode in
                guard let self else { return }
                if mode == .expanded, lastMode != .expanded, !pointer.isCaptured { CursorControl.warp(to: expandedHome) }
                lastMode = mode
                routeMouse(nil)
            }
            .store(in: &cancellables)
    }

    private func routeMouse(_ event: NSEvent?) {
        if pointer.isCaptured {
            guard state.absorbsCursor else { return pointer.release(toward: .zero) }
            if let event, event.type == .mouseMoved || event.type == .leftMouseDragged { pointer.dragged(by: event) }
            return
        }
        followPointer()
        MenuBarGuard.keepAway(NSEvent.mouseLocation, panel: frame, island: state.hitFrame)
        if state.absorbsCursor, pointer.canCapture { pointer.capture() }
    }

    private func applyFrame() {
        setFrame(Self.frame(on: geometry.screen, size: state.canvasSize), display: true)
    }

    private static func frame(on screen: NSScreen, size: CGSize) -> NSRect {
        NSRect(x: screen.frame.midX - size.width / 2, y: screen.frame.maxY - size.height, width: size.width, height: size.height)
    }
}
