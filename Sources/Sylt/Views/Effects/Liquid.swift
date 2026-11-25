import SwiftUI

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

enum Ripple {
    private static let height: CGFloat = 3.6

    static func reach(strength: Double) -> CGFloat { height * CGFloat(strength) }

    static func rim(in rect: CGRect, shape: IslandShape, origin: CGPoint, at t: TimeInterval, strength: Double, width: Double, step: CGFloat) -> [(point: CGPoint, normal: CGVector, swell: CGFloat)]? {
        let time = CGFloat(t)
        let decay = exp(-2.8 * time)
        guard decay > 0.04 else { return nil }
        let height = Self.height * CGFloat(strength)
        let spread = CGFloat(width)
        let outline = shape.outline(in: rect, step: step, includingEdges: true)
        guard outline.count > 1 else { return nil }
        var nearest = 0
        var best = CGFloat.greatestFiniteMagnitude
        for (index, sample) in outline.enumerated() {
            let gap = hypot(sample.point.x - origin.x, sample.point.y - origin.y)
            if gap < best { best = gap; nearest = index }
        }
        return outline.enumerated().map { index, sample in
            let distance = CGFloat(abs(index - nearest)) * step
            let wave = sin(distance / (9 * spread) - time * 18) * exp(-distance / (24 * spread))
            return (sample.point, sample.normal, max(0, wave) * height * decay)
        }
    }

    static func path(in rect: CGRect, shape: IslandShape, origin: CGPoint, at t: TimeInterval, strength: Double, width: Double, rest: CGFloat = -0.5) -> Path {
        guard let rim = rim(in: rect, shape: shape, origin: origin, at: t, strength: strength, width: width, step: 1) else { return Path() }
        var path = Path()
        for (index, sample) in rim.enumerated() {
            let out = sample.swell + rest
            let point = CGPoint(x: sample.point.x + sample.normal.dx * out, y: sample.point.y + sample.normal.dy * out)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}
