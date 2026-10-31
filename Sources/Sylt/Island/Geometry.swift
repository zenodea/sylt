import CoreGraphics

extension CGVector {
    var push: CGVector { CGVector(dx: dx, dy: max(0, dy)) }

    var pushes: Bool { push.length > 0.001 }

    var length: CGFloat { hypot(dx, dy) }

    var unit: CGVector {
        let length = length
        return length > 0 ? CGVector(dx: dx / length, dy: dy / length) : .zero
    }
}

extension CGRect {
    func clamp(_ point: CGPoint) -> CGPoint {
        CGPoint(x: min(max(point.x, minX), maxX), y: min(max(point.y, minY), maxY))
    }
}
