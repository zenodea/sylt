import SwiftUI

struct IslandShape: Shape {
    var frame: IslandFrame
    var radius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(AnimatablePair(frame.size.width, frame.size.height), frame.centerOffset), radius) }
        set {
            frame = IslandFrame(size: CGSize(width: newValue.first.first.first, height: newValue.first.first.second), centerOffset: newValue.first.second)
            radius = newValue.second
        }
    }

    var cornerRadius: CGFloat {
        max(0, min(radius, frame.size.height / 2, frame.size.width / 2))
    }

    func origin(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX - frame.size.width / 2 + frame.centerOffset, y: rect.minY)
    }

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
