import SwiftUI

/// Minutes until the next event, with a calendar glyph.
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

/// Remaining time on the countdown, with a draining ring.
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

struct TimerRing: View {
    let fraction: Double
    var size: CGFloat = 12
    var lineWidth: CGFloat = 2

    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.25), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, fraction))
                .stroke(.orange, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.linear(duration: 1), value: fraction)
        }
        .frame(width: size, height: size)
    }
}

/// Orange for the microphone, green for the camera, like the menu bar.
struct PrivacyDots: View {
    let use: PrivacyMonitor.Use

    var body: some View {
        HStack(spacing: 3) {
            if use.microphone { dot(.orange) }
            if use.camera { dot(.green) }
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.8), radius: 3)
            .transition(.scale.combined(with: .opacity))
    }
}

/// Audio accessory charge, kept in the wing while it is connected.
struct HeadphonesBadge: View {
    let device: BluetoothMonitor.Device

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: device.name.localizedCaseInsensitiveContains("airpods") ? "airpodspro" : "headphones")
                .font(.system(size: 11, weight: .semibold))
            Text("\(device.battery ?? 0)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle((device.battery ?? 100) <= 20 ? Color.red : .white.opacity(0.85))
    }
}

/// Condition glyph and temperature.
struct WeatherBadge: View {
    let report: WeatherMonitor.Report

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: report.symbol)
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.multicolor)
            Text("\(Int(report.temperature.rounded()))°")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}
