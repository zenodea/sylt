import SwiftUI

/// The held pointer: mouse travel is a push the island leans into, measured from where
/// the pointer went in, until it pops out through the rim where the push leads.
extension IslandState {
    /// Mouse travel that frees the pointer at the default release force.
    static let baseReleaseDistance: CGFloat = 520
    /// How quickly the lean saturates with travel.
    static let pullSoftness: CGFloat = 320
    /// How much of the island's lean the content follows.
    private static let contentLean: CGFloat = 0.6

    var releaseDistance: CGFloat { Self.baseReleaseDistance * CGFloat(preferences.releaseForce) }

    /// The island just took the pointer at this canvas point.
    func cursorHeld(at point: CGPoint) {
        heldOrigin = point
        pointerArrived(at: point)
    }

    func cursorPushed(_ travel: CGVector) {
        let push = travel.push
        withAnimation(IslandAnimation.cursor) {
            cursorPull = CGVector(dx: tanh(push.dx / Self.pullSoftness), dy: tanh(push.dy / Self.pullSoftness))
            cursor = CGPoint(x: cursorPull.dx * Self.contentLean, y: cursorPull.dy * Self.contentLean)
            pullStrength = min(1, push.length / releaseDistance)
            exitPoint = rimPoint(toward: push, outside: 0)
        }
    }

    /// The mouse stopped: the island settles back with a soft spring.
    func cursorSettled() {
        withAnimation(IslandAnimation.swipeRebound) {
            cursorPull = .zero
            cursor = .zero
            pullStrength = 0
        }
    }

    func cursorReleased(toward direction: CGVector) {
        if direction.pushes {
            flash(toward: direction)
            if preferences.hapticsOnRelease { Haptics.peek() }
        }
        cursorSettled()
        hoverChanged(false)
    }

    /// Where a push in this direction meets the island's rim, optionally a little past it,
    /// in canvas coordinates, starting from where the pointer went in.
    func rimPoint(toward travel: CGVector, outside: CGFloat) -> CGPoint {
        let island = layout.hitFrame(for: mode, hovering: true).insetBy(dx: 1, dy: 1)
        let origin = heldOrigin.map { CGPoint(x: min(max($0.x, island.minX), island.maxX), y: min(max($0.y, island.minY), island.maxY)) }
            ?? CGPoint(x: island.midX, y: island.midY)
        let push = travel.push
        guard travel.pushes else { return origin }
        var scale = CGFloat.greatestFiniteMagnitude
        if push.dx != 0 { scale = min(scale, ((push.dx > 0 ? island.maxX : island.minX) - origin.x) / push.dx) }
        if push.dy > 0 { scale = min(scale, (island.maxY - origin.y) / push.dy) }
        let unit = push.unit
        return CGPoint(x: origin.x + push.dx * scale + unit.dx * outside, y: origin.y + push.dy * scale + unit.dy * outside)
    }

    /// Reach within which a free pointer makes the rim glow.
    static let approachReach: CGFloat = 70

    /// Called with the free pointer's canvas position; the glow follows the nearest rim
    /// point and brightens as the gap closes, fading out beyond reach.
    func cursorApproached(_ point: CGPoint) {
        guard preferences.approachGlow, mode != .expanded, !isHovering else { return clearApproach() }
        let island = layout.hitFrame(for: mode, hovering: false).insetBy(dx: IslandLayout.hitMargin, dy: 0)
        let nearest = CGPoint(x: min(max(point.x, island.minX), island.maxX), y: min(max(point.y, island.minY), island.maxY))
        let gap = hypot(point.x - nearest.x, point.y - nearest.y)
        guard gap < Self.approachReach else { return clearApproach() }
        withAnimation(IslandAnimation.cursor) {
            approachPoint = nearest
            approachStrength = 1 - gap / Self.approachReach
        }
    }

    func clearApproach() {
        guard approachStrength > 0 else { return }
        withAnimation(IslandAnimation.cursor) { approachStrength = 0 }
    }
}
