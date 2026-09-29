import SwiftUI

struct HUDView: View {
    let kind: HUDKind
    let layout: IslandLayout
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var volume: VolumeMonitor
    @EnvironmentObject private var brightness: BrightnessMonitor
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var herdr: HerdrMonitor

    var body: some View {
        Group {
            switch kind.style {
            case .compact(let leading, let trailing): wings(leading: leading, trailing: trailing)
            case .twoRow(let wing): VStack(spacing: 0) { wings(leading: wing, trailing: wing); row }
            case .card: card
            }
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
    }

    private func wings(leading leadingWidth: Double, trailing trailingWidth: Double) -> some View {
        HStack(spacing: 0) {
            leading
                .frame(width: max(0, leadingWidth - 8), alignment: .leading)
                .padding(.leading, leadingWidth > 0 ? 8 : 0)
            Spacer().frame(width: layout.notchWidth)
            trailing
                .frame(width: max(0, trailingWidth - 8), alignment: .trailing)
                .padding(.trailing, trailingWidth > 0 ? 8 : 0)
        }
        .frame(height: layout.notchHeight + 2)
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
    }

    @ViewBuilder
    private var leading: some View {
        switch kind {
        case .volume: Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        case .brightness: Image(systemName: "sun.max.fill")
        case .battery: BatteryGlyph(snapshot: battery.snapshot, compact: true)
        case .agentFinished(let agent):
            HStack(spacing: 6) {
                Text("🐑").font(.system(size: 13))
                HarnessIcon(harness: agent.harness, size: 16)
                Text(agent.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        case .nowPlaying:
            if let track = nowPlaying.track { ArtworkView(image: track.artwork, size: layout.artworkSize) }
        case .notification, .unlocked: EmptyView()
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch kind {
        case .volume: LevelBar(value: volume.isMuted ? 0 : Double(volume.level))
        case .brightness: LevelBar(value: Double(brightness.level))
        case .battery(let alert):
            Text(batteryMessage(alert))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(batteryColor(alert))
                .lineLimit(1)
        case .nowPlaying:
            if let track = nowPlaying.track { AudioBars(isPlaying: nowPlaying.isPlaying, colors: track.barColors) }
        case .agentFinished, .notification, .unlocked: EmptyView()
        }
    }

    @ViewBuilder
    private var row: some View {
        if let track = nowPlaying.track {
            MarqueeText(text: track.artist.isEmpty ? track.title : "\(track.title)  ·  \(track.artist)")
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: IslandLayout.hudRowHeight)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: layout.notchHeight - 4)
            if case .notification(let notification) = kind {
                HStack(spacing: 10) {
                    if let icon = notification.icon {
                        Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "bell.fill").frame(width: 28, height: 28)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(notification.title).lineLimit(1)
                        Text(notification.body).lineLimit(1)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tapped() {
        if case .agentFinished(let agent) = kind { herdr.focus(agent) }
    }

    private func batteryMessage(_ alert: BatteryAlert) -> String {
        switch alert {
        case .powerSource: battery.snapshot.onAC ? "Charging" : "On battery"
        case .level(100): "Fully charged"
        case .level(let percent) where percent <= 10: "Critically low"
        case .level(let percent) where percent <= 20: "Low battery"
        case .level: "Battery"
        }
    }

    private func batteryColor(_ alert: BatteryAlert) -> Color {
        if case .level(let percent) = alert, percent <= 20 { return .red }
        return .white.opacity(0.8)
    }
}
