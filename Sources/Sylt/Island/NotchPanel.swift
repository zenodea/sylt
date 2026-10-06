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
    private let host: IslandHostingView
    /// While captured, the pointer is parked at the island's centre and mouse
    /// movement pulls the island instead; a shove this far pops the pointer out.
    private var captured = false
    private var lastMode = IslandMode.closed
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
    /// How far below the top of the screen the held pointer is kept.
    private static let topMargin: CGFloat = 10
    /// How far beyond the island's sides a free pointer is still kept off the top edge.
    private static let menuBarGuardMargin: CGFloat = 60
    private static let recaptureDelay: CFTimeInterval = 0.15
    /// The pull decays as time passes between movements, so only a fast,
    /// deliberate shove reaches the release distance. A single quick flick
    /// above this speed lets go at once.
    private static let decayPerSecond: CGFloat = 0.02
    private static let flickSpeed: CGFloat = 6500

    init(screen: NSScreen, state: IslandState, openSettings: @escaping () -> Void) {
        self.state = state
        self.geometry = NotchGeometry(screen: screen)
        host = IslandHostingView(rootView: IslandView(state: state, openSettings: openSettings))
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
        host.state = state
        contentView = host
        applyFrame()
        SkyLight.pinAboveLockScreen(self)
        trackCursor()
        TrackpadTouch.shared.start()
        TrackpadTouch.shared.onChange = { [weak self] touching in
            guard let self, captured, !touching else { return }
            settle()
        }
    }

    deinit {
        mouseMonitors.forEach(NSEvent.removeMonitor)
    }

    override func constrainFrameRect(_ frameRect: NSRect, to screen: NSScreen?) -> NSRect { frameRect }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Only a real change of screen or notch moves anything; the menu bar sliding in and
    /// out also fires a screen change and must not.
    func relayout(on screen: NSScreen) {
        let next = NotchGeometry(screen: screen)
        guard next != geometry else { return }
        geometry = next
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
            // Scrolls reach the recogniser from anywhere over the island, lists included.
            NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
                guard let self, state.isHovering || captured else { return event }
                return host.handleScroll(event) ? nil : event
            } as Any,
        ]
        state.lock.$isLocked
            .combineLatest(state.$mode)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _, mode in
                guard let self else { return }
                // A free pointer that opened the island by click or swipe is centred under the notch too.
                if mode == .expanded, lastMode != .expanded, !captured {
                    CursorControl.warp(to: screenPoint(of: CGPoint(x: state.canvasSize.width / 2, y: state.notchHeight + 16)))
                }
                lastMode = mode
                routeMouse(nil)
            }
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
        let island = state.hitFrame.insetBy(dx: -Self.menuBarGuardMargin, dy: 0)
        TopEdgeGuard.shared.guardSpan((frame.minX + island.minX) ... (frame.minX + island.maxX))
        keepMenuBarAway(at: location)
        if state.absorbsCursor, CACurrentMediaTime() - releasedAt > Self.recaptureDelay { capture() }
    }

    /// Touching the top of the screen brings the menu bar out over the island. Anywhere
    /// across the island's span, the pointer is nudged back down before that can happen.
    private func keepMenuBarAway(at location: CGPoint) {
        guard location.y >= frame.maxY - 1 else { return }
        let island = state.hitFrame.insetBy(dx: -Self.menuBarGuardMargin, dy: 0)
        guard (frame.minX + island.minX ... frame.minX + island.maxX).contains(location.x) else { return }
        CursorControl.warp(to: cgPoint(CGPoint(x: location.x, y: frame.maxY - 2)))
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
        // Entering means touching the top of the screen, which is where fullscreen apps
        // reveal the menu bar. The hidden pointer is moved off that edge at once.
        if entry.y > frame.maxY - Self.topMargin {
            entry.y = frame.maxY - Self.topMargin
            CursorControl.warp(to: cgPoint(entry))
        }
        lastDrag = CACurrentMediaTime()
        state.cursorPushed(.zero)
        if state.preferences.releaseEffect == .ripple {
            state.cursorAbsorbed(at: CGPoint(x: entry.x - frame.minX, y: frame.maxY - entry.y))
        }
    }

    private func dragged(by event: NSEvent) {
        // The warp that parks the pointer can report one large delta; it isn't the user's.
        if ignoreNextDelta { ignoreNextDelta = false; return }
        let now = CACurrentMediaTime()
        // Not holding: the first real movement takes the pointer straight back out that way.
        if !state.preferences.holdsPointer {
            let travel = CGVector(dx: event.deltaX, dy: event.deltaY)
            return release(toward: hypot(travel.dx, max(0, travel.dy)) > 0.001 ? travel : CGVector(dx: 1, dy: 0))
        }
        if now - capturedAt < Self.settleAfterCapture { lastDrag = now; pull = .zero; return }
        let dt = max(0.001, now - lastDrag)
        let decay = pow(Self.decayPerSecond, CGFloat(dt))
        lastDrag = now
        pull.dx = pull.dx * decay + event.deltaX
        pull.dy = pull.dy * decay + event.deltaY
        let speed = hypot(event.deltaX, max(0, event.deltaY)) / CGFloat(dt)
        let force = CGFloat(state.preferences.releaseForce)
        if hypot(pull.dx, max(0, pull.dy)) >= state.releaseDistance || speed >= Self.flickSpeed * force { return release(toward: pull) }
        state.cursorPushed(pull)
        keepOffScreenTop()
        rest?.invalidate()
        // A finger on the trackpad is still holding: the island keeps its lean until it
        // lifts. Without a trackpad to ask, a short pause in movement counts as letting go.
        guard !TrackpadTouch.shared.isTouching else { return }
        rest = .after(0.12) { [weak self] in self?.settle() }
    }

    /// The hand let go: the island springs back and the hidden pointer is parked.
    private func settle() {
        guard captured else { return }
        rest?.invalidate()
        rest = nil
        pull = .zero
        state.cursorSettled()
        parkPointer()
    }

    /// The hidden pointer drifts with the mouse while held. Once the mouse rests, it is
    /// set back where it went in, so a two-finger swipe lands on the island and not on
    /// whatever the pointer wandered over. Pushes never warp, so the push force is untouched.
    private func parkPointer() {
        let location = NSEvent.mouseLocation
        guard hypot(location.x - entry.x, location.y - entry.y) > 2 else { return }
        CursorControl.warp(to: cgPoint(entry))
        ignoreNextDelta = true
    }

    /// The hidden pointer still moves with the mouse. If it reaches the top of the screen
    /// the menu bar would come out from under the island, so it is set back down to where
    /// it went in. Pushing up never counts toward a release, so the lost delta costs nothing.
    private func keepOffScreenTop() {
        let location = NSEvent.mouseLocation
        guard location.y > frame.maxY - Self.topMargin else { return }
        CursorControl.warp(to: cgPoint(CGPoint(x: location.x, y: entry.y)))
        ignoreNextDelta = true
    }

    /// Give the pointer back. A shove throws it past the rim where it was pushed;
    /// anything else (opening the panel, locking) shows it right where it is.
    private func release(toward direction: CGVector) {
        captured = false
        pull = .zero
        rest?.invalidate()
        rest = nil
        let ejected = hypot(direction.dx, max(0, direction.dy)) > 0.001
        // Opening the island hands the pointer back centred just under the notch, inside
        // the open panel, so it never lands outside and closes it again.
        let home = state.mode == .expanded
            ? screenPoint(of: CGPoint(x: state.canvasSize.width / 2, y: state.notchHeight + 16))
            : cgPoint(entry)
        CursorControl.warp(to: ejected ? screenPoint(of: state.rimPoint(toward: direction, outside: Self.ejectDistance)) : home)
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
