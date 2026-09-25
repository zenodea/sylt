import SwiftUI

struct ExpandedView: View {
    @ObservedObject var state: IslandState
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var volume: VolumeMonitor
    @EnvironmentObject private var herdr: HerdrMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Spacer().frame(height: state.notchHeight - 6)
            HStack(spacing: 16) {
                StatusCard(title: "Battery") { batteryRow }
                StatusCard(title: "Volume") { volumeRow }
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
        HStack(spacing: 8) {
            Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
            Slider(
                value: Binding(get: { Double(volume.level) }, set: { volume.set(Float($0)) }),
                in: 0...1
            )
            .controlSize(.small)
        }
    }
}
