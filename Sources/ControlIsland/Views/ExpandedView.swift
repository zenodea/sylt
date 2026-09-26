import SwiftUI

struct ExpandedView: View {
    @ObservedObject var state: IslandState
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var volume: VolumeMonitor
    @EnvironmentObject private var brightness: BrightnessMonitor
    @EnvironmentObject private var herdr: HerdrMonitor
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: state.notchHeight - 6)
            if nowPlaying.track != nil {
                MediaCard(nowPlaying: nowPlaying)
            }
            HStack(spacing: 16) {
                if preferences.isEnabled(.battery), battery.snapshot.hasBattery {
                    StatusCard(title: "Battery") { batteryRow }
                }
                if preferences.isEnabled(.volume) {
                    StatusCard(title: "Volume") { volumeRow }
                }
                if preferences.isEnabled(.brightness), brightness.available {
                    StatusCard(title: "Brightness") { brightnessRow }
                }
            }
            if herdr.available {
                HerdrSection(herdr: herdr)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 18)
        .padding(.bottom, 14)
    }

    private var batteryRow: some View {
        HStack {
            BatteryGlyph(snapshot: battery.snapshot, compact: false)
            Spacer()
            Text(batteryDetail).foregroundStyle(.white.opacity(0.6))
        }
    }

    private var batteryDetail: String {
        let snapshot = battery.snapshot
        if let minutes = snapshot.minutesRemaining {
            return Duration.seconds(minutes * 60).formatted(.units(allowed: [.hours, .minutes], width: .narrow))
                + (snapshot.isCharging ? " to full" : " left")
        }
        return snapshot.onAC ? "Plugged in" : ""
    }

    private var volumeRow: some View {
        LevelSlider(
            symbol: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
            value: volume.level,
            onChange: volume.set
        )
    }

    private var brightnessRow: some View {
        LevelSlider(symbol: "sun.max.fill", value: brightness.level, onChange: brightness.set)
    }
}
