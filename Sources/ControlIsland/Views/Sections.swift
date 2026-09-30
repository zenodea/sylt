import SwiftUI
import UniformTypeIdentifiers

/// The next event: when, what, and a join button for calls.
struct EventRow: View {
    let event: CalendarMonitor.Event

    var body: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(event.start, format: .dateTime.hour().minute())
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(event.end, format: .dateTime.hour().minute())
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
                    .monospacedDigit()
            }
            .frame(width: 40, alignment: .leading)
            Text(event.title).lineLimit(1)
            Spacer()
            if let url = event.joinURL {
                Button {
                    NSWorkspace.shared.open(url)
                    Haptics.press()
                } label: {
                    Label("Join", systemImage: "video.fill")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.green.opacity(0.9), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: IslandLayout.eventRowHeight)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

/// Presets to start a countdown, or the running one with a cancel.
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

/// Files parked on the island; drag one out to use it.
struct ShelfSection: View {
    @ObservedObject var shelf: ShelfMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Shelf", systemImage: "tray.full.fill")
                Spacer()
                Button("Clear") { shelf.clear() }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(shelf.files, id: \.self) { url in
                        VStack(spacing: 2) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                                .resizable()
                                .frame(width: 28, height: 28)
                            Text(url.lastPathComponent)
                                .font(.system(size: 9))
                                .lineLimit(1)
                                .frame(width: 52)
                        }
                        .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                        .onTapGesture { NSWorkspace.shared.open(url) }
                        .contextMenu {
                            Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                            Button("Remove") { shelf.remove(url) }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(IslandAnimation.value, value: shelf.files)
        }
        .frame(height: IslandLayout.shelfHeight)
    }
}

/// Recent copies; a click puts one back on the pasteboard.
struct ClipboardSection: View {
    @ObservedObject var clipboard: ClipboardMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Clipboard", systemImage: "doc.on.clipboard.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            VStack(spacing: 3) {
                ForEach(clipboard.items.prefix(IslandLayout.maxClipboardRows)) { item in
                    Button {
                        clipboard.copy(item)
                        Haptics.press()
                    } label: {
                        HStack {
                            Text(item.preview).lineLimit(1)
                            Spacer()
                            Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: IslandLayout.clipboardRowHeight - 3)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

/// Conditions, temperature and the day's range.
struct WeatherRow: View {
    let report: WeatherMonitor.Report

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: report.symbol)
                .font(.system(size: 18))
                .symbolRenderingMode(.multicolor)
                .frame(width: 24)
            Text("\(Int(report.temperature.rounded()))°")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(report.summary).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("H \(Int(report.high.rounded()))°  L \(Int(report.low.rounded()))°")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .monospacedDigit()
            if !report.place.isEmpty {
                Text(report.place)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: IslandLayout.weatherRowHeight)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}

struct Pill: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(IslandAnimation.press, value: configuration.isPressed)
    }
}
