import SwiftUI

/// While the island is being moved: an outline at each corner and at the middle of each edge,
/// the one it will settle into filled in.
struct PlacementTargets: View {
    let layout: IslandLayout

    private static let radius: CGFloat = 16

    var body: some View {
        let closed = layout.frame(for: .closed, hovering: false)
        ZStack(alignment: .topLeading) {
            ForEach(IslandPlacement.targets.indices, id: \.self) { index in
                let target = IslandPlacement.targets[index]
                let chosen = target == layout.placement
                let shape = outline(for: target, size: closed)
                shape.fill(.black.opacity(chosen ? 0.35 : 0.15))
                shape.stroke(.white.opacity(chosen ? 0.95 : 0.6), style: StrokeStyle(lineWidth: 1.5, dash: chosen ? [] : [5, 4]))
                    .shadow(color: .black.opacity(0.35), radius: 1.5)
            }
        }
        .allowsHitTesting(false)
    }

    private func outline(for target: IslandPlacement, size: IslandFrame) -> IslandShape {
        var placed = layout
        placed.placement = target
        let anchor = placed.anchor
        let frame = IslandFrame(size: size.size, centerOffset: 0)
        return IslandShape(frame: frame, origin: anchor.rect(for: frame).origin, flush: anchor.flush, radius: Self.radius)
    }
}
