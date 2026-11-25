import SwiftUI

/// The island's visible outline as an open path: down the left side, around the bottom, up
/// the right and back along the top. Sides along the screen's edge are left out.
struct RimOutline: Shape {
    var shape: IslandShape

    var animatableData: IslandShape.AnimatableData {
        get { shape.animatableData }
        set { shape.animatableData = newValue }
    }

    private static let step: CGFloat = 2

    func path(in rect: CGRect) -> Path {
        var path = Path()
        var last: CGPoint?
        for sample in shape.outline(in: rect, step: Self.step) {
            // A side left out leaves a gap, which the path jumps rather than cuts across.
            if let last, hypot(sample.point.x - last.x, sample.point.y - last.y) <= Self.step * 2 {
                path.addLine(to: sample.point)
            } else {
                path.move(to: sample.point)
            }
            last = sample.point
        }
        return path
    }
}
