import SwiftUI

/// The island outline, hugging the top of its rect, centred on the notch plus
/// an offset. Animates size and offset without moving the content behind it.
struct IslandShape: Shape {
    var frame: IslandFrame
    var notchHeight: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(frame.size.width, frame.size.height), frame.centerOffset) }
        set { frame = IslandFrame(size: CGSize(width: newValue.first.first, height: newValue.first.second), centerOffset: newValue.second) }
    }

    var cornerRadius: CGFloat {
        min(10 + max(0, frame.size.height - notchHeight) * 0.35, 28, frame.size.height / 2)
    }

    func origin(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX - frame.size.width / 2 + frame.centerOffset, y: rect.minY)
    }

    /// The visible outline sampled about every `step` points, from the top of the left
    /// side, down and around the bottom, to the top of the right side, with the outward
    /// normal at each sample. Consecutive samples are a known distance apart, so an index
    /// difference is a distance along the rim.
    func outline(in rect: CGRect, step: CGFloat) -> [(point: CGPoint, normal: CGVector)] {
        let size = frame.size
        let origin = origin(in: rect)
        let radius = cornerRadius
        var samples: [(point: CGPoint, normal: CGVector)] = []
        let sideHeight = size.height - radius
        for i in 0...Int(sideHeight / step) {
            samples.append((CGPoint(x: origin.x, y: origin.y + CGFloat(i) * step), CGVector(dx: -1, dy: 0)))
        }
        func arc(around centre: CGPoint, from: CGFloat, to: CGFloat) {
            let count = max(1, Int(abs(to - from) * radius / step))
            for i in 0...count {
                let angle = from + (to - from) * CGFloat(i) / CGFloat(count)
                samples.append((CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius), CGVector(dx: cos(angle), dy: sin(angle))))
            }
        }
        arc(around: CGPoint(x: origin.x + radius, y: origin.y + sideHeight), from: .pi, to: .pi / 2)
        let bottomWidth = size.width - 2 * radius
        for i in 0...Int(bottomWidth / step) {
            samples.append((CGPoint(x: origin.x + radius + CGFloat(i) * step, y: origin.y + size.height), CGVector(dx: 0, dy: 1)))
        }
        arc(around: CGPoint(x: origin.x + size.width - radius, y: origin.y + sideHeight), from: .pi / 2, to: 0)
        for i in 0...Int(sideHeight / step) {
            samples.append((CGPoint(x: origin.x + size.width, y: origin.y + sideHeight - CGFloat(i) * step), CGVector(dx: 1, dy: 0)))
        }
        return samples
    }

    func path(in rect: CGRect) -> Path {
        let size = frame.size
        let origin = origin(in: rect)
        let radius = cornerRadius
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        ).path(in: CGRect(origin: origin, size: size))
    }
}
