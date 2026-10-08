import AppKit

/// A free pointer touching the top of the screen brings the menu bar out over the island.
/// Across the island's span, and a margin either side, it is kept off that edge: a HID
/// tap rewrites the position before macOS sees it, and a nudge back down covers the rest.
@MainActor
enum MenuBarGuard {
    private static let sideMargin: CGFloat = 60
    private static let edgeDepth: CGFloat = 2

    /// `location` is in Cocoa screen coordinates, `island` in the panel's canvas coordinates.
    static func keepAway(_ location: CGPoint, panel: CGRect, island: CGRect) {
        let span = (panel.minX + island.minX - sideMargin) ... (panel.minX + island.maxX + sideMargin)
        TopEdgeGuard.shared.guardSpan(span)
        guard location.y >= panel.maxY - 1, span.contains(location.x) else { return }
        CursorControl.warp(to: CGPoint(x: location.x, y: panel.maxY - edgeDepth))
    }
}
