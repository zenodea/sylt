import SwiftUI

/// Leans the island toward a swipe by growing the far edge, so the edge over the notch
/// and the top edge never move.
struct SwipeStretch: ViewModifier {
    let pull: CGVector
    /// The edge that stays put: the one away from the swipe, on the attached side.
    let anchor: UnitPoint

    func body(content: Content) -> some View {
        content.scaleEffect(
            x: 1 + abs(pull.dx) * 0.025,
            y: 1 + abs(pull.dy) * 0.05,
            anchor: anchor
        )
    }
}
