import AppKit
import SwiftUI

/// Only the island itself accepts mouse events; the rest of the canvas is inert.
final class IslandHostingView: NSHostingView<IslandView> {
    weak var state: IslandState?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let state else { return nil }
        let hit = state.layout.hitFrame(for: state.mode)
        let rect = CGRect(x: hit.minX, y: bounds.maxY - hit.maxY, width: hit.width, height: hit.height)
        return rect.contains(point) ? super.hitTest(point) : nil
    }
}
