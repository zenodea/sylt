import AppKit
import SwiftUI

/// Only the island itself accepts mouse events; the rest of the canvas is inert.
final class IslandHostingView: NSHostingView<IslandView> {
    weak var state: IslandState?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let state else { return nil }
        let island = state.islandSize
        let rect = CGRect(
            x: bounds.midX - island.width / 2,
            y: bounds.maxY - island.height,
            width: island.width,
            height: island.height
        )
        return rect.contains(point) ? super.hitTest(point) : nil
    }
}
