import AppKit
import SwiftUI

/// Only the island itself accepts mouse events; the rest of the canvas is inert.
final class IslandHostingView: NSHostingView<IslandView> {
    weak var state: IslandState?

    private var swipe = CGVector.zero
    /// Set once a swipe has been acted on, so one gesture triggers one action.
    private var swipeFired = false
    /// Over a scrolling list the gesture is the list's first: only a long hard flick
    /// closes the island or turns the page.
    private var overList = false
    private var upwardTravel: CGFloat = 0
    private var peakUpward: CGFloat = 0
    private var sidewaysTravel: CGFloat = 0
    private var peakSideways: CGFloat = 0
    private static let hardTravel: CGFloat = 120
    private static let hardFlick: CGFloat = 20
    /// Over a list the island doesn't lean until the sideways travel is clearly a swipe.
    private static let intentTravel: CGFloat = 18

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    /// Feeds a scroll event to the swipe recogniser. Returns true when the event is a
    /// sideways swipe on the open island, which no list underneath should also scroll.
    @discardableResult
    func handleScroll(_ event: NSEvent) -> Bool {
        guard let state, event.momentumPhase.isEmpty else { return false }
        switch event.phase {
        case .began:
            swipe = .zero
            swipeFired = false
            upwardTravel = 0
            peakUpward = 0
            sidewaysTravel = 0
            peakSideways = 0
            overList = isOverList(event)
        case .changed:
            let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
            let dy = event.scrollingDeltaY * sign
            let dx = event.scrollingDeltaX * sign
            swipe.dx = Self.clamp(swipe.dx + dx)
            swipe.dy = Self.clamp(swipe.dy + dy)
            if dy < 0 { upwardTravel -= dy; peakUpward = max(peakUpward, -dy) }
            sidewaysTravel += abs(dx)
            peakSideways = max(peakSideways, abs(dx))
            if !overList || sidewaysTravel >= Self.intentTravel || upwardTravel >= Self.hardTravel {
                state.swipeMoved(swipe)
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

    /// Over a list, closing needs a long hard flick upward; everything else swipes as usual.
    private func allows(_ direction: SwipeDirection) -> Bool {
        guard direction == .up, overList, state?.mode == .expanded else { return true }
        return upwardTravel >= Self.hardTravel && peakUpward >= Self.hardFlick
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
