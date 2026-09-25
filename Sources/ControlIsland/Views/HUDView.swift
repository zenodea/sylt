import SwiftUI

struct HUDView: View {
    let kind: HUDKind
    let notchHeight: CGFloat
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var volume: VolumeMonitor

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
        case .battery:
            HStack(spacing: 10) {
                BatteryGlyph(snapshot: battery.snapshot, compact: false)
                Text(battery.snapshot.onAC ? "Charging" : "On battery")
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
    }
}
