import SwiftUI

/// A short shower of bright specks thrown out along a push, or drawn in to where the
/// pointer arrived.
struct Sparks: View {
    let event: SparkEvent
    private static let count = 16
    private static let life: TimeInterval = 0.6

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSince(event.start)
            Canvas { graphics, _ in
                guard t < Self.life else { return }
                for index in 0..<Self.count {
                    let spark = Self.spark(index, at: t, event: event)
                    guard spark.alpha > 0.02 else { continue }
                    let rect = CGRect(x: spark.position.x - spark.size / 2, y: spark.position.y - spark.size / 2, width: spark.size, height: spark.size)
                    graphics.fill(Circle().path(in: rect), with: .color(spark.colour.opacity(spark.alpha)))
                }
            }
            .blendMode(.plusLighter)
        }
        .allowsHitTesting(false)
    }

    private static func spark(_ index: Int, at t: TimeInterval, event: SparkEvent) -> (position: CGPoint, size: CGFloat, alpha: Double, colour: Color) {
        let seed = CGFloat((index * 73) % 17) / 16
        let seed2 = CGFloat((index * 31) % 13) / 12
        let base = event.inward ? CGFloat(index) / CGFloat(count) * .pi * 2 : atan2(event.direction.dy, event.direction.dx)
        let angle = base + (event.inward ? 0 : (seed - 0.5) * 1.6)
        let speed: CGFloat = 90 + seed2 * 180
        let drag: CGFloat = 5
        let time = CGFloat(t)
        let travel = speed * (1 - exp(-drag * time)) / drag
        let reach = event.inward ? max(0, 26 + seed * 20 - travel) : travel
        let position = CGPoint(x: event.point.x + cos(angle) * reach, y: event.point.y + sin(angle) * reach)
        let fade = max(0, 1 - Double(time) / life)
        let colour = seed2 > 0.6 ? Color(red: 1, green: 0.85, blue: 0.5) : .white
        return (position, 1.4 + seed * 1.6, fade * fade, colour)
    }
}
