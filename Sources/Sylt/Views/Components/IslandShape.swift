import SwiftUI

/// The island's outline. Its sides along the screen's edge (the top under a notch, two sides
/// in a corner, none while floating) stay square; every other corner is rounded.
struct IslandShape: Shape {
    var frame: IslandFrame
    /// The island's top-left corner on the canvas.
    var origin: CGPoint
    var flush: FlushEdges = .top
    var radius: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat>, AnimatablePair<CGFloat, AnimatablePair<CGFloat, CGFloat>>> {
        get {
            AnimatablePair(
                AnimatablePair(AnimatablePair(frame.size.width, frame.size.height), frame.centerOffset),
                AnimatablePair(radius, AnimatablePair(origin.x, origin.y))
            )
        }
        set {
            frame = IslandFrame(size: CGSize(width: newValue.first.first.first, height: newValue.first.first.second), centerOffset: newValue.first.second)
            radius = newValue.second.first
            origin = CGPoint(x: newValue.second.second.first, y: newValue.second.second.second)
        }
    }

    var cornerRadius: CGFloat {
        max(0, min(radius, frame.size.height / 2, frame.size.width / 2))
    }

    func origin(in rect: CGRect) -> CGPoint {
        CGPoint(x: rect.minX + origin.x, y: rect.minY + origin.y)
    }

    private struct Radii {
        var topLeading: CGFloat, topTrailing: CGFloat, bottomLeading: CGFloat, bottomTrailing: CGFloat
    }

    private var radii: Radii {
        let r = cornerRadius
        func corner(_ a: FlushEdges, _ b: FlushEdges) -> CGFloat { flush.contains(a) || flush.contains(b) ? 0 : r }
        return Radii(
            topLeading: corner(.top, .leading), topTrailing: corner(.top, .trailing),
            bottomLeading: corner(.bottom, .leading), bottomTrailing: corner(.bottom, .trailing)
        )
    }

    /// Points around the visible outline with their outward normals. It runs down the left
    /// side, along the bottom, up the right side and back along the top, so under a notch it
    /// starts at the top-left corner. The sides along the screen's edge are left out, or with
    /// `includingEdges` kept with no normal, so a closed path follows them and nothing moves there.
    func outline(in rect: CGRect, step: CGFloat, includingEdges: Bool = false) -> [(point: CGPoint, normal: CGVector)] {
        let size = frame.size
        let o = origin(in: rect)
        let (minX, minY, maxX, maxY) = (o.x, o.y, o.x + size.width, o.y + size.height)
        let r = radii
        var samples: [(point: CGPoint, normal: CGVector)] = []
        func line(from start: CGPoint, to end: CGPoint, normal: CGVector) {
            let length = hypot(end.x - start.x, end.y - start.y)
            guard length > 0 else { return }
            for i in 0...Int(length / step) {
                let t = CGFloat(i) * step / length
                samples.append((CGPoint(x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t), normal))
            }
        }
        func arc(around centre: CGPoint, radius: CGFloat, from: CGFloat, to: CGFloat) {
            guard radius > 0 else { return }
            let count = max(1, Int(abs(to - from) * radius / step))
            for i in 0...count {
                let angle = from + (to - from) * CGFloat(i) / CGFloat(count)
                samples.append((CGPoint(x: centre.x + cos(angle) * radius, y: centre.y + sin(angle) * radius), CGVector(dx: cos(angle), dy: sin(angle))))
            }
        }
        func side(_ edge: FlushEdges, from start: CGPoint, to end: CGPoint, normal: CGVector) {
            if !flush.contains(edge) { line(from: start, to: end, normal: normal) } else if includingEdges { line(from: start, to: end, normal: .zero) }
        }
        side(.leading, from: CGPoint(x: minX, y: minY + r.topLeading), to: CGPoint(x: minX, y: maxY - r.bottomLeading), normal: CGVector(dx: -1, dy: 0))
        arc(around: CGPoint(x: minX + r.bottomLeading, y: maxY - r.bottomLeading), radius: r.bottomLeading, from: .pi, to: .pi / 2)
        side(.bottom, from: CGPoint(x: minX + r.bottomLeading, y: maxY), to: CGPoint(x: maxX - r.bottomTrailing, y: maxY), normal: CGVector(dx: 0, dy: 1))
        arc(around: CGPoint(x: maxX - r.bottomTrailing, y: maxY - r.bottomTrailing), radius: r.bottomTrailing, from: .pi / 2, to: 0)
        side(.trailing, from: CGPoint(x: maxX, y: maxY - r.bottomTrailing), to: CGPoint(x: maxX, y: minY + r.topTrailing), normal: CGVector(dx: 1, dy: 0))
        arc(around: CGPoint(x: maxX - r.topTrailing, y: minY + r.topTrailing), radius: r.topTrailing, from: 0, to: -.pi / 2)
        side(.top, from: CGPoint(x: maxX - r.topTrailing, y: minY), to: CGPoint(x: minX + r.topLeading, y: minY), normal: CGVector(dx: 0, dy: -1))
        arc(around: CGPoint(x: minX + r.topLeading, y: minY + r.topLeading), radius: r.topLeading, from: -.pi / 2, to: -.pi)
        return samples
    }

    func path(in rect: CGRect) -> Path {
        let r = radii
        return UnevenRoundedRectangle(
            topLeadingRadius: r.topLeading,
            bottomLeadingRadius: r.bottomLeading,
            bottomTrailingRadius: r.bottomTrailing,
            topTrailingRadius: r.topTrailing,
            style: .continuous
        ).path(in: CGRect(origin: origin(in: rect), size: frame.size))
    }
}
