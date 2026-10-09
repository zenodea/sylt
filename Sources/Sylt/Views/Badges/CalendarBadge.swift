import SwiftUI

struct CalendarBadge: View {
    let event: CalendarMonitor.Event

    /// Room for the symbol and the widest countdown, so the wing never resizes as it counts.
    static let width: CGFloat = 12 + 3 + TextWidth.of("99m", size: 11, monospacedDigits: true)

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 3) {
                Image(systemName: "calendar").font(.system(size: 11, weight: .semibold))
                Text(Self.countdown(to: event.start, now: context.date))
                    .font(.badge)
                    .monospacedDigit()
                    .fixedSize()
            }
            .foregroundStyle(event.start.timeIntervalSince(context.date) < 5 * 60 ? Color.orange : .white.opacity(0.85))
        }
    }

    static func countdown(to start: Date, now: Date) -> String {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes <= 0 ? "now" : "\(minutes)m"
    }
}
