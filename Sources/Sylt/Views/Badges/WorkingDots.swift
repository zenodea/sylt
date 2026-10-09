import SwiftUI

/// Three dots rising in turn while an agent works, drawn in a canvas so the row's
/// layout never changes.
struct WorkingDots: View {
    private static let size: CGFloat = 4
    private static let pitch: CGFloat = 7
    private static let rise: CGFloat = 3
    private static let period = 1.2

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24)) { context in
            Canvas { graphics, size in
                let time = context.date.timeIntervalSinceReferenceDate
                for index in 0..<3 {
                    let lift = Self.lift(index: index, time: time)
                    graphics.fill(Circle().path(in: Self.dot(index: index, lift: lift, height: size.height)), with: .color(.green.opacity(0.5 + lift * 0.5)))
                }
            }
        }
        .frame(width: 18, height: 10)
    }

    private static func lift(index: Int, time: TimeInterval) -> Double {
        let phase: Double = time * 2 * .pi / period - Double(index) * 0.9
        return max(0, sin(phase))
    }

    private static func dot(index: Int, lift: Double, height: CGFloat) -> CGRect {
        let x: CGFloat = CGFloat(index) * pitch
        let y: CGFloat = height - size - CGFloat(lift) * rise
        return CGRect(x: x, y: y, width: size, height: size)
    }
}
