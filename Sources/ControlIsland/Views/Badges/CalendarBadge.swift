import SwiftUI

struct CalendarBadge: View {
    let event: CalendarMonitor.Event

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 3) {
                Image(systemName: "calendar").font(.system(size: 11, weight: .semibold))
                Text(Self.countdown(to: event.start, now: context.date))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(event.start.timeIntervalSince(context.date) < 5 * 60 ? Color.orange : .white.opacity(0.85))
        }
    }

    static func countdown(to start: Date, now: Date) -> String {
        let minutes = Int((start.timeIntervalSince(now) / 60).rounded(.up))
        return minutes <= 0 ? "now" : "\(minutes)m"
    }
}
