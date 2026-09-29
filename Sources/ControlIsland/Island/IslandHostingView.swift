import AppKit
import SwiftUI

/// Only the island itself accepts mouse events; the rest of the canvas is inert.
final class IslandHostingView: NSHostingView<IslandView> {
    weak var state: IslandState?

    private var swipe = CGVector.zero

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard let state, event.momentumPhase.isEmpty else { return }
        switch event.phase {
        case .began:
            swipe = .zero
        case .changed:
            let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
            swipe.dx += event.scrollingDeltaX * sign
            swipe.dy += event.scrollingDeltaY * sign
            state.swipeMoved(swipe)
        case .ended:
            if let direction = SwipeDirection(vector: swipe) { state.swiped(direction) }
            state.swipeEnded()
        case .cancelled:
            state.swipeEnded()
        default:
            break
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let state else { return nil }
        let hit = state.hitFrame
        let rect = CGRect(x: hit.minX, y: bounds.maxY - hit.maxY, width: hit.width, height: hit.height)
        return rect.contains(point) ? super.hitTest(point) : nil
    }
}
