import SwiftUI

struct ClosedView: View {
    @ObservedObject var state: IslandState
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var herdr: HerdrMonitor

    var body: some View {
        HStack(spacing: 0) {
            leftWing.frame(width: state.wingWidth)
            Spacer().frame(width: state.notchWidth)
            rightWing.frame(width: state.wingWidth)
        }
        .frame(height: state.notchHeight)
    }

    private var leftWing: some View {
        HStack(spacing: 5) {
            if herdr.available {
                StatusDot(active: herdr.workingCount > 0)
                Text("\(herdr.workingCount)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
    }

    private var rightWing: some View {
        Group {
            if battery.snapshot.hasBattery {
                BatteryGlyph(snapshot: battery.snapshot, compact: true)
            }
        }
    }
}
