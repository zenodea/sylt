import SwiftUI

struct TimerBadge: View {
    @ObservedObject var timer: TimerMonitor

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let remaining = timer.remaining(at: context.date)
            HStack(spacing: 4) {
                TimerRing(fraction: timer.duration > 0 ? remaining / timer.duration : 0, size: 12)
                Text(Self.clock(remaining))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(.white.opacity(0.85))
        }
    }

    static func clock(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return total >= 3600 ? String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60) : String(format: "%d:%02d", total / 60, total % 60)
    }
}
