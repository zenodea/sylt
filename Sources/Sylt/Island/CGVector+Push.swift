import CoreGraphics

extension CGVector {
    /// This travel as a push on the island: the upward part is dropped, the screen ends there.
    var push: CGVector { CGVector(dx: dx, dy: max(0, dy)) }

    /// Whether this travel pushes the island anywhere at all.
    var pushes: Bool { push.length > 0.001 }

    var length: CGFloat { hypot(dx, dy) }

    var unit: CGVector {
        let length = length
        return length > 0 ? CGVector(dx: dx / length, dy: dy / length) : .zero
    }
}
