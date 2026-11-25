import SwiftUI

extension IslandState {
    static let baseReleaseDistance: CGFloat = 520
    static let pullSoftness: CGFloat = 320
    private static let contentLean: CGFloat = 0.6

    var releaseDistance: CGFloat { Self.baseReleaseDistance * CGFloat(preferences.releaseForce) }

    func push(_ travel: CGVector) -> CGVector { travel.push(away: layout.anchor.flush) }

    func pushes(_ travel: CGVector) -> Bool { travel.pushes(away: layout.anchor.flush) }

    func cursorHeld(at point: CGPoint) {
        heldOrigin = point
        pointerArrived(at: point)
    }

    func cursorPushed(_ travel: CGVector) {
        let push = push(travel)
        withAnimation(IslandAnimation.cursor) {
            cursorPull = CGVector(dx: tanh(push.dx / Self.pullSoftness), dy: tanh(push.dy / Self.pullSoftness))
            cursor = CGPoint(x: cursorPull.dx * Self.contentLean, y: cursorPull.dy * Self.contentLean)
            pullStrength = min(1, push.length / releaseDistance)
            exitPoint = rimPoint(toward: push, outside: 0)
        }
    }

    func cursorSettled() {
        withAnimation(IslandAnimation.swipeRebound) {
            cursorPull = .zero
            cursor = .zero
            pullStrength = 0
        }
    }

    func cursorReleased(toward direction: CGVector) {
        if pushes(direction) {
            flash(toward: direction)
            if preferences.hapticsOnRelease { Haptics.peek() }
        }
        cursorSettled()
        hoverChanged(false)
    }

    func rimPoint(toward travel: CGVector, outside: CGFloat) -> CGPoint {
        let island = layout.hitFrame(for: mode, hovering: true).insetBy(dx: 1, dy: 1)
        let origin = heldOrigin.map(island.clamp) ?? CGPoint(x: island.midX, y: island.midY)
        let push = push(travel)
        guard push.isMovement else { return origin }
        var scale = CGFloat.greatestFiniteMagnitude
        if push.dx != 0 { scale = min(scale, ((push.dx > 0 ? island.maxX : island.minX) - origin.x) / push.dx) }
        if push.dy != 0 { scale = min(scale, ((push.dy > 0 ? island.maxY : island.minY) - origin.y) / push.dy) }
        let unit = push.unit
        return CGPoint(x: origin.x + push.dx * scale + unit.dx * outside, y: origin.y + push.dy * scale + unit.dy * outside)
    }

    static let approachReach: CGFloat = 70

    func cursorApproached(_ point: CGPoint) {
        guard preferences.approachGlow, mode != .expanded, !isHovering else { return clearApproach() }
        let island = layout.hitFrame(for: mode, hovering: false).insetBy(dx: IslandLayout.hitMargin, dy: 0)
        let nearest = island.clamp(point)
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
