import AppKit

/// Holds the pointer while it's over the island. The hidden pointer is parked where it
/// went in and mouse travel becomes a push on the island; a hard enough shove, or a
/// quick flick, throws it back out past the rim where the push led.
@MainActor
final class PointerCapture {
    private(set) var isCaptured = false
    private let state: IslandState
    private unowned let panel: NotchPanel
    private var pull = CGVector.zero
    /// Where the pointer was taken, in Cocoa screen coordinates.
    private var entry = CGPoint.zero
    private var lastDrag = CACurrentMediaTime()
    private var capturedAt: CFTimeInterval = 0
    private var releasedAt: CFTimeInterval = 0
    private var rest: Timer?
    /// A warp shows up as one large delta on the next event; it isn't the user's.
    private var ignoreNextDelta = false

    /// For a moment after taking the pointer, how fast it arrived doesn't count as a push.
    private static let settleAfterCapture: CFTimeInterval = 0.25
    private static let recaptureDelay: CFTimeInterval = 0.15
    /// How far past the rim the pointer is thrown.
    private static let ejectDistance: CGFloat = 4
    /// How far below the top of the screen the held pointer is kept.
    private static let topMargin: CGFloat = 10
    /// The pull decays between movements, so only a fast, deliberate shove reaches the
    /// release distance; a single flick above this speed lets go at once.
    private static let decayPerSecond: CGFloat = 0.02
    private static let flickSpeed: CGFloat = 6500
    /// Without a trackpad to ask, a pause in movement this long counts as letting go.
    private static let restDelay: TimeInterval = 0.12
    private static let parkTolerance: CGFloat = 2

    init(state: IslandState, panel: NotchPanel) {
        self.state = state
        self.panel = panel
        TrackpadTouch.shared.start()
        TrackpadTouch.shared.onChange = { [weak self] touching in
            if !touching { self?.settle() }
        }
    }

    var canCapture: Bool { CACurrentMediaTime() - releasedAt > Self.recaptureDelay }

    /// Hides the pointer where it is. It isn't moved while held: a warp shows up as a
    /// mouse delta on the next event and would read as a flick.
    func capture() {
        isCaptured = true
        pull = .zero
        entry = NSEvent.mouseLocation
        capturedAt = CACurrentMediaTime()
        lastDrag = capturedAt
        // Entering means touching the top of the screen, where fullscreen apps reveal the menu bar.
        if entry.y > panel.frame.maxY - Self.topMargin {
            entry.y = panel.frame.maxY - Self.topMargin
            CursorControl.warp(to: entry)
        }
        if state.preferences.releaseEffect == .blackHole {
            BlackHoleWarp.suckIn(from: entry, to: panel.islandCentre, while: { [weak self] in self?.isCaptured == true }) { [weak self] end in
                guard let self else { return }
                entry = end
                CursorControl.hide(on: panel.screen)
            }
        } else {
            CursorControl.hide(on: panel.screen)
        }
        ignoreNextDelta = true
        state.cursorPushed(.zero)
        state.cursorHeld(at: panel.canvasPoint(of: entry))
    }

    func dragged(by event: NSEvent) {
        if ignoreNextDelta { ignoreNextDelta = false; return }
        let travel = CGVector(dx: event.deltaX, dy: event.deltaY)
        guard state.preferences.holdsPointer else {
            return release(toward: travel.pushes ? travel : CGVector(dx: 1, dy: 0))
        }
        let now = CACurrentMediaTime()
        let dt = max(0.001, now - lastDrag)
        lastDrag = now
        guard now - capturedAt >= Self.settleAfterCapture else { return pull = .zero }
        let decay = pow(Self.decayPerSecond, CGFloat(dt))
        pull = CGVector(dx: pull.dx * decay + travel.dx, dy: pull.dy * decay + travel.dy)
        let speed = travel.push.length / CGFloat(dt)
        let force = CGFloat(state.preferences.releaseForce)
        if pull.push.length >= state.releaseDistance || speed >= Self.flickSpeed * force { return release(toward: pull) }
        state.cursorPushed(pull)
        keepOffScreenTop()
        rest?.invalidate()
        // A finger on the trackpad is still holding: the island keeps its lean until it lifts.
        guard !TrackpadTouch.shared.isTouching else { return }
        rest = .after(Self.restDelay) { [weak self] in self?.settle() }
    }

    /// Gives the pointer back. A shove throws it past the rim where it was pushed; anything
    /// else (opening the panel, locking) shows it where it is, or inside the open panel.
    func release(toward direction: CGVector) {
        isCaptured = false
        pull = .zero
        rest?.invalidate()
        releasedAt = CACurrentMediaTime()
        let ejected = direction.pushes
        let destination = ejected
            ? panel.screenPoint(of: state.rimPoint(toward: direction, outside: Self.ejectDistance))
            : state.mode == .expanded ? panel.expandedHome : entry
        CursorControl.warp(to: destination)
        CursorControl.show()
        if ejected {
            state.cursorReleased(toward: direction)
            if state.preferences.releaseEffect == .blackHole { BlackHoleWarp.fling(toward: direction) }
            panel.ignoresMouseEvents = true
        } else {
            state.cursorSettled()
            panel.followPointer()
        }
    }

    /// The hand let go: the island springs back and the hidden pointer is parked.
    private func settle() {
        guard isCaptured else { return }
        rest?.invalidate()
        pull = .zero
        state.cursorSettled()
        parkPointer()
    }

    /// The hidden pointer drifts with the mouse while held. Once the mouse rests it goes
    /// back where it went in, so a two-finger swipe lands on the island and not on
    /// whatever the pointer wandered over.
    private func parkPointer() {
        let location = NSEvent.mouseLocation
        guard hypot(location.x - entry.x, location.y - entry.y) > Self.parkTolerance else { return }
        warpHidden(to: entry)
    }

    /// At the top of the screen the menu bar would come out from under the island, so the
    /// hidden pointer is set back down to where it went in. Pushing up never counts toward
    /// a release, so the lost delta costs nothing.
    private func keepOffScreenTop() {
        let location = NSEvent.mouseLocation
        guard location.y > panel.frame.maxY - Self.topMargin else { return }
        warpHidden(to: CGPoint(x: location.x, y: entry.y))
    }

    /// Pushes never warp, so the push force is untouched: the delta a warp makes is dropped.
    private func warpHidden(to point: CGPoint) {
        CursorControl.warp(to: point)
        ignoreNextDelta = true
    }
}
