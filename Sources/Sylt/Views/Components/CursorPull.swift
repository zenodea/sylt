import SwiftUI

/// Stretches the island a little toward the pointer it holds.
struct CursorPull: ViewModifier {
    let cursor: CGPoint
    let enabled: Bool
    /// Where the island is attached; it stretches away from there.
    var anchor: UnitPoint = .top

    func body(content: Content) -> some View {
        let pull = enabled ? cursor : .zero
        content
            .scaleEffect(x: 1 + abs(pull.x) * 0.015, y: 1 + abs(pull.y) * 0.06, anchor: anchor)
            .animation(IslandAnimation.cursor, value: pull)
    }
}
