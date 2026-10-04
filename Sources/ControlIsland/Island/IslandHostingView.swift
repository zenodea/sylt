import AppKit
import SwiftUI

/// Only the island itself accepts mouse events; the rest of the canvas is inert.
final class IslandHostingView: NSHostingView<IslandView> {
    weak var state: IslandState?

    private var swipe = CGVector.zero
    /// Set once a swipe has been acted on, so one gesture triggers one action.
    private var swipeFired = false
    /// Beyond this the island is fully pulled; winding further would only delay a reversal.
    private static let swipeLimit: CGFloat = 60

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard let state, event.momentumPhase.isEmpty else { return }
        switch event.phase {
        case .began:
            swipe = .zero
            swipeFired = false
        case .changed:
            let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
            swipe.dx = Self.clamp(swipe.dx + event.scrollingDeltaX * sign)
            swipe.dy = Self.clamp(swipe.dy + event.scrollingDeltaY * sign)
            state.swipeMoved(swipe)
            // Act while the fingers are still down: that's the only time the trackpad can tap back.
            if !swipeFired, let direction = SwipeDirection(vector: swipe) {
                swipeFired = true
                state.swiped(direction)
            }
        case .ended:
            if !swipeFired, let direction = SwipeDirection(vector: swipe) { state.swiped(direction) }
            state.swipeEnded()
        case .cancelled:
            state.swipeEnded()
        default:
            break
        }
    }

    private static func clamp(_ value: CGFloat) -> CGFloat {
        min(max(value, -swipeLimit), swipeLimit)
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let state else { return nil }
        let hit = state.hitFrame
        let rect = CGRect(x: hit.minX, y: bounds.maxY - hit.maxY, width: hit.width, height: hit.height)
        return rect.contains(point) ? super.hitTest(point) : nil
    }
}
