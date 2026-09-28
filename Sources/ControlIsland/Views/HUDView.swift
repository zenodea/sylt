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
            if kind.isCompact { compact } else { card }
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
    }

    private var compact: some View {
        HStack(spacing: 0) {
            compactLeading
                .frame(width: layout.compactWingWidth, alignment: .leading)
                .padding(.leading, 14)
            Spacer().frame(width: layout.notchWidth)
            compactTrailing
                .frame(width: layout.compactWingWidth, alignment: .trailing)
                .padding(.trailing, 14)
        }
        .frame(height: layout.notchHeight + 2)
    }

    @ViewBuilder
    private var compactLeading: some View {
        switch kind {
        case .volume: Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
        case .brightness: Image(systemName: "sun.max.fill")
        case .battery: BatteryGlyph(snapshot: battery.snapshot, compact: true)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var compactTrailing: some View {
        switch kind {
        case .volume: LevelBar(value: volume.isMuted ? 0 : Double(volume.level))
        case .brightness: LevelBar(value: Double(brightness.level))
        case .battery(let alert):
            Text(batteryMessage(alert))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(batteryColor(alert))
                .lineLimit(1)
        default: EmptyView()
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: layout.notchHeight - 4)
            switch kind {
            case .agentFinished(let agent): agentRow(agent)
            case .nowPlaying: nowPlayingRow
            default: EmptyView()
            }
        }
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }

    private func agentRow(_ agent: HerdrAgent) -> some View {
        Button { herdr.focus(agent) } label: {
            HStack(spacing: 10) {
                HarnessIcon(harness: agent.harness, size: 28)
                VStack(alignment: .leading, spacing: 1) {
                    Text(agent.title).lineLimit(1)
                    Text("\(agent.harness.title) finished grazing · click to open").lineLimit(1)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                Text("🐑").font(.system(size: 18))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var nowPlayingRow: some View {
        if let track = nowPlaying.track {
            HStack(spacing: 10) {
                ArtworkView(image: track.artwork, size: 30)
                VStack(alignment: .leading, spacing: 1) {
                    Text(track.title).lineLimit(1)
                    Text(track.artist).lineLimit(1)
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer(minLength: 0)
                AudioBars(isPlaying: nowPlaying.isPlaying, colors: track.barColors)
            }
        }
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
