import AppKit
import SwiftUI

final class IslandHostingView: NSHostingView<IslandView> {
    weak var state: IslandState?

    private var swipe = CGVector.zero
    private var swipeFired = false
    private var overList = false
    private var sidewaysTravel: CGFloat = 0
    private var peakSideways: CGFloat = 0
    private static let intentTravel: CGFloat = 18

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    @discardableResult
    func handleScroll(_ event: NSEvent) -> Bool {
        guard let state, event.momentumPhase.isEmpty else { return false }
        switch event.phase {
        case .began:
            swipe = .zero
            swipeFired = false
            sidewaysTravel = 0
            peakSideways = 0
            overList = isOverList(event)
        case .changed:
            let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
            let dy = event.scrollingDeltaY * sign
            let dx = event.scrollingDeltaX * sign
            swipe.dx = Self.clamp(swipe.dx + dx)
            swipe.dy = Self.clamp(swipe.dy + dy)
            sidewaysTravel += abs(dx)
            peakSideways = max(peakSideways, abs(dx))
            if !overList {
                state.swipeMoved(swipe)
            } else if sidewaysTravel >= Self.intentTravel {
                state.swipeMoved(CGVector(dx: swipe.dx, dy: 0))
            }
            // Acted on while the fingers are still down: the only time the trackpad can tap back.
            if !swipeFired, let direction = SwipeDirection(vector: swipe), allows(direction) {
                swipeFired = true
                state.swiped(direction)
            }
        case .ended:
            if !swipeFired, let direction = SwipeDirection(vector: swipe), allows(direction) { state.swiped(direction) }
            state.swipeEnded()
        case .cancelled:
            state.swipeEnded()
        default:
            break
        }
        return state.mode == .expanded && abs(swipe.dx) > abs(swipe.dy)
    }

    private func allows(_ direction: SwipeDirection) -> Bool {
        guard overList, state?.mode == .expanded else { return true }
        switch direction {
        case .up, .down: return false
        case .left, .right: return sidewaysTravel >= Self.intentTravel
        }
    }

    private func isOverList(_ event: NSEvent) -> Bool {
        guard let state else { return false }
        let point = CGPoint(x: event.locationInWindow.x, y: bounds.maxY - event.locationInWindow.y)
        return state.listFrames.contains { $0.contains(point) }
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, -IslandState.swipeReach), IslandState.swipeReach)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let state else { return nil }
        let hit = state.hitFrame
        let rect = CGRect(x: hit.minX, y: bounds.maxY - hit.maxY, width: hit.width, height: hit.height)
        return rect.contains(point) ? super.hitTest(point) : nil
    }
}
