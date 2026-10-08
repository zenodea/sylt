import SwiftUI

/// The island's liquid surface, mounted all the time so it moves with the island's own
/// spring; a `LiquidEvent` plays a ripple from the edge where the pointer went in or out.
struct Liquid: View, Animatable {
    var shape: IslandShape
    let event: LiquidEvent?
    let strength: Double
    let width: Double

    var animatableData: IslandShape.AnimatableData {
        get { shape.animatableData }
        set { shape.animatableData = newValue }
    }

    var body: some View {
        TimelineView(.animation(paused: event == nil)) { context in
            Canvas { graphics, size in
                guard let event else { return }
                let t = context.date.timeIntervalSince(event.start)
                graphics.fill(Ripple.path(in: CGRect(origin: .zero, size: size), shape: shape, origin: event.point, at: t, strength: strength, width: width), with: .color(.black))
            }
        }
        .allowsHitTesting(false)
    }
}

/// A damped wave along the rim that only ever bulges outward, so nothing behind the island
/// is uncovered: the whole outline, nudged inside wherever the surface is still.
private enum Ripple {
    private static let height: CGFloat = 3.6
    private static let step: CGFloat = 1

    static func path(in rect: CGRect, shape: IslandShape, origin: CGPoint, at t: TimeInterval, strength: Double, width: Double) -> Path {
        let time = CGFloat(t)
        let decay = exp(-2.8 * time)
        guard decay > 0.04 else { return Path() }
        let height = Self.height * CGFloat(strength)
        let spread = CGFloat(width)
        let outline = shape.outline(in: rect, step: step)
        guard outline.count > 1 else { return Path() }
        var nearest = 0
        var best = CGFloat.greatestFiniteMagnitude
        for (index, sample) in outline.enumerated() {
            let gap = hypot(sample.point.x - origin.x, sample.point.y - origin.y)
            if gap < best { best = gap; nearest = index }
        }
        var path = Path()
        for (index, sample) in outline.enumerated() {
            let distance = CGFloat(abs(index - nearest)) * step
            let wave = sin(distance / (9 * spread) - time * 18) * exp(-distance / (24 * spread))
            let swell = max(0, wave) * height * decay - 0.5
            let point = CGPoint(x: sample.point.x + sample.normal.dx * swell, y: sample.point.y + sample.normal.dy * swell)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
