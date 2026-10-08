import SwiftUI

/// The island's visible outline as an open path: down the left side, around the bottom and
/// up the right. The top edge is the screen's edge and is left out.
struct RimOutline: Shape {
    var shape: IslandShape

    var animatableData: IslandShape.AnimatableData {
        get { shape.animatableData }
        set { shape.animatableData = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (index, sample) in shape.outline(in: rect, step: 2).enumerated() {
            if index == 0 { path.move(to: sample.point) } else { path.addLine(to: sample.point) }
        }
        return path
    }
}
