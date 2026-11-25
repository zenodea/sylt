import CoreGraphics

extension CGVector {
    /// The part of a movement that leads away from the screen edges the island lies along:
    /// pushing into the edge goes nowhere.
    func push(away flush: FlushEdges) -> CGVector {
        CGVector(
            dx: flush.contains(.leading) && dx < 0 || flush.contains(.trailing) && dx > 0 ? 0 : dx,
            dy: flush.contains(.top) && dy < 0 || flush.contains(.bottom) && dy > 0 ? 0 : dy
        )
    }

    func pushes(away flush: FlushEdges) -> Bool { push(away: flush).isMovement }

    var isMovement: Bool { length > 0.001 }

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
