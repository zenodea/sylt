import AppKit
import SwiftUI

/// Only the island itself accepts mouse events; the rest of the canvas is inert.
final class IslandHostingView: NSHostingView<IslandView> {
    weak var state: IslandState?

    private var swipe = CGVector.zero
    private var swipeHandled = false

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func scrollWheel(with event: NSEvent) {
        guard let state else { return super.scrollWheel(with: event) }
        switch event.phase {
        case .began:
            swipe = .zero
            swipeHandled = false
        case .changed:
            let sign: CGFloat = event.isDirectionInvertedFromDevice ? 1 : -1
            swipe.dx += event.scrollingDeltaX * sign
            swipe.dy += event.scrollingDeltaY * sign
            guard !swipeHandled, let direction = SwipeDirection(vector: swipe) else { return }
            swipeHandled = true
            state.swiped(direction)
        default:
            break
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let state else { return nil }
        let hit = state.layout.hitFrame(for: state.mode)
        let rect = CGRect(x: hit.minX, y: bounds.maxY - hit.maxY, width: hit.width, height: hit.height)
        return rect.contains(point) ? super.hitTest(point) : nil
    }
}
