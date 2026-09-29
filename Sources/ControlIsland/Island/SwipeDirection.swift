import CoreGraphics

/// Direction the fingers moved on the trackpad.
enum SwipeDirection {
    case up, down, left, right

    private static let threshold: CGFloat = 40

    init?(vector: CGVector) {
        guard max(abs(vector.dx), abs(vector.dy)) >= Self.threshold else { return nil }
        if abs(vector.dy) >= abs(vector.dx) {
            self = vector.dy > 0 ? .down : .up
        } else {
            self = vector.dx > 0 ? .right : .left
        }
    }
}
