import SwiftUI

struct TimerSection: View {
    @ObservedObject var timer: TimerMonitor

    var body: some View {
        HStack(spacing: 8) {
            if timer.isRunning {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    let remaining = timer.remaining(at: context.date)
                    HStack(spacing: 8) {
                        TimerRing(fraction: timer.duration > 0 ? remaining / timer.duration : 0, size: 18, lineWidth: 2.5)
                        Text(TimerBadge.clock(remaining))
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                    }
                }
                Spacer()
                Button("Cancel") { timer.cancel(); Haptics.press() }
                    .buttonStyle(Pill(tint: .white.opacity(0.12)))
            } else {
                Image(systemName: "timer").foregroundStyle(.white.opacity(0.6))
                ForEach(TimerMonitor.presets, id: \.self) { preset in
                    Button(Self.label(preset)) { timer.begin(preset); Haptics.expand() }
                        .buttonStyle(Pill(tint: .white.opacity(0.1)))
                }
                Spacer()
            }
        }
        .padding(.horizontal, 10)
        .frame(height: IslandLayout.timerRowHeight)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
        .animation(IslandAnimation.value, value: timer.isRunning)
    }

    private static func label(_ seconds: TimeInterval) -> String {
        seconds >= 3600 ? "\(Int(seconds / 3600)) h" : "\(Int(seconds / 60)) min"
    }
}
