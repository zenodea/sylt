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
    /// While captured, the pointer is parked at the island's centre and mouse
    /// movement pulls the island instead; a shove this far pops the pointer out.
    private var captured = false
    private var pull = CGVector.zero
    /// Where the pointer was when the island took it, in screen coordinates.
    private var entry = CGPoint.zero
    private var lastDrag = CACurrentMediaTime()
    private var rest: Timer?
    private var ignoreNextDelta = false
    private var releasedAt: CFTimeInterval = 0
    private var capturedAt: CFTimeInterval = 0
    /// For a moment after taking the pointer the island ignores how fast it
    /// arrived, so a quick entry doesn't count as a push.
    private static let settleAfterCapture: CFTimeInterval = 0.25
    /// How far past the rim the pointer is thrown, and how long before it can be taken in again.
    private static let ejectDistance: CGFloat = 4
    private static let recaptureDelay: CFTimeInterval = 0.15
    /// The pull decays as time passes between movements, so only a fast,
    /// deliberate shove reaches the release distance. A single quick flick
    /// above this speed lets go at once.
    private static let decayPerSecond: CGFloat = 0.02
    private static let flickSpeed: CGFloat = 6500

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
            NSEvent.addGlobalMonitorForEvents(matching: events) { [weak self] event in self?.routeMouse(event) } as Any,
            NSEvent.addLocalMonitorForEvents(matching: events) { [weak self] event in
                self?.routeMouse(event)
                return event
            } as Any,
        ]
        state.lock.$isLocked
            .combineLatest(state.$mode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, _ in self?.routeMouse(nil) }
            .store(in: &cancellables)
    }

    private func routeMouse(_ event: NSEvent?) {
        if captured {
            guard state.absorbsCursor else { return release(toward: .zero) }
            if let event, event.type == .mouseMoved || event.type == .leftMouseDragged { dragged(by: event) }
            return
        }
        let location = NSEvent.mouseLocation
        state.cursorMoved(to: CGPoint(x: location.x - frame.minX, y: frame.maxY - location.y))
        ignoresMouseEvents = state.lock.isLocked || !state.isHovering
        if state.absorbsCursor, CACurrentMediaTime() - releasedAt > Self.recaptureDelay { capture() }
    }

    /// Hide the pointer where it is. It is not moved while held: a warp shows up
    /// as a mouse delta on the next event and would read as a flick.
    private func capture() {
        captured = true
        pull = .zero
        entry = NSEvent.mouseLocation
        capturedAt = CACurrentMediaTime()
        CursorControl.hide(on: screen)
        ignoreNextDelta = true
        lastDrag = CACurrentMediaTime()
        state.cursorPushed(.zero)
    }

    private func dragged(by event: NSEvent) {
        // The warp that parks the pointer can report one large delta; it isn't the user's.
        if ignoreNextDelta { ignoreNextDelta = false; return }
        let now = CACurrentMediaTime()
        if now - capturedAt < Self.settleAfterCapture { lastDrag = now; pull = .zero; return }
        let dt = max(0.001, now - lastDrag)
        let decay = pow(Self.decayPerSecond, CGFloat(dt))
        lastDrag = now
        pull.dx = pull.dx * decay + event.deltaX
        pull.dy = pull.dy * decay + event.deltaY
        let speed = hypot(event.deltaX, max(0, event.deltaY)) / CGFloat(dt)
        if hypot(pull.dx, max(0, pull.dy)) >= IslandState.releaseDistance || speed >= Self.flickSpeed { return release(toward: pull) }
        state.cursorPushed(pull)
        // When the mouse comes to rest, the island settles back in one spring.
        rest?.invalidate()
        rest = .after(0.12) { [weak self] in
            guard let self, captured else { return }
            pull = .zero
            state.cursorSettled()
        }
    }

    /// Give the pointer back. A shove throws it past the rim where it was pushed;
    /// anything else (opening the panel, locking) shows it right where it is.
    private func release(toward direction: CGVector) {
        captured = false
        pull = .zero
        rest?.invalidate()
        rest = nil
        let ejected = hypot(direction.dx, max(0, direction.dy)) > 0.001
        CursorControl.warp(to: ejected ? screenPoint(of: state.rimPoint(toward: direction, outside: Self.ejectDistance)) : cgPoint(entry))
        CursorControl.show()
        releasedAt = CACurrentMediaTime()
        if ejected {
            state.cursorReleased(toward: direction)
            ignoresMouseEvents = true
        } else {
            state.cursorSettled()
            let location = NSEvent.mouseLocation
            state.cursorMoved(to: CGPoint(x: location.x - frame.minX, y: frame.maxY - location.y))
            ignoresMouseEvents = state.lock.isLocked || !state.isHovering
        }
    }


    /// Canvas point (top-left origin) to CoreGraphics screen coordinates (top-left of the main display).
    private func screenPoint(of point: CGPoint) -> CGPoint {
        cgPoint(CGPoint(x: frame.minX + point.x, y: frame.maxY - point.y))
    }

    private func cgPoint(_ cocoa: CGPoint) -> CGPoint {
        CGPoint(x: cocoa.x, y: NSScreen.screens[0].frame.height - cocoa.y)
    }

    private func applyFrame() {
        let size = state.canvasSize
        let screenFrame = geometry.screen.frame
        let origin = CGPoint(x: screenFrame.midX - size.width / 2, y: screenFrame.maxY - size.height)
        setFrame(NSRect(origin: origin, size: size), display: true)
    }
}
