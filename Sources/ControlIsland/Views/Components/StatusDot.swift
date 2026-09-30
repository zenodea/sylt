import SwiftUI

/// Green and breathing while an agent works; amber and still while it waits.
struct StatusDot: View {
    let working: Bool
    var size: CGFloat = 6

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !working)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let pulse = working ? (sin(t * 2 * .pi / 1.6) + 1) / 2 : 0
            Circle()
                .fill(working ? Color.green : Color.orange)
                .frame(width: size, height: size)
                .scaleEffect(1 + pulse * 0.3)
                .opacity(0.7 + pulse * 0.3)
        }
        .animation(IslandAnimation.value, value: working)
    }
}
