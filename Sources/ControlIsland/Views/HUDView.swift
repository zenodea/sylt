import SwiftUI

struct HUDView: View {
    let kind: HUDKind
    let notchHeight: CGFloat
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var volume: VolumeMonitor
    @EnvironmentObject private var brightness: BrightnessMonitor
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var herdr: HerdrMonitor

    var body: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: notchHeight - 4)
            row
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 22)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var row: some View {
        switch kind {
        case .volume:
            HStack(spacing: 10) {
                Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                LevelBar(value: volume.isMuted ? 0 : Double(volume.level))
            }
        case .brightness:
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                LevelBar(value: Double(brightness.level))
            }
        case .battery(let alert):
            HStack(spacing: 10) {
                BatteryGlyph(snapshot: battery.snapshot, compact: false)
                Text(batteryMessage(alert))
                    .foregroundStyle(.white.opacity(0.8))
            }
        case .agentFinished(let agent):
            Button { herdr.focus(agent) } label: {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(agent.title).lineLimit(1)
                        Text("\(agent.agent) finished · click to focus").lineLimit(1)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        case .nowPlaying:
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
                    AudioBars(isPlaying: nowPlaying.isPlaying)
                }
            }
        }
    }

    private func batteryMessage(_ alert: BatteryAlert) -> String {
        switch alert {
        case .powerSource: battery.snapshot.onAC ? "Charging" : "On battery"
        case .level(100): "Fully charged"
        case .level(let percent) where percent <= 10: "Battery critically low"
        case .level(let percent) where percent <= 20: "Battery low"
        case .level: "Battery remaining"
        }
    }
}
