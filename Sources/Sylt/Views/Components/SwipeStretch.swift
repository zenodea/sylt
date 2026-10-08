import SwiftUI

/// Leans the island toward a swipe by growing the far edge, so the edge over the notch
/// and the top edge never move.
struct SwipeStretch: ViewModifier {
    let pull: CGVector

    func body(content: Content) -> some View {
        content.scaleEffect(
            x: 1 + abs(pull.dx) * 0.025,
            y: 1 + max(0, pull.dy) * 0.05,
            anchor: UnitPoint(x: pull.dx > 0 ? 0 : 1, y: 0)
        )
    }
}
