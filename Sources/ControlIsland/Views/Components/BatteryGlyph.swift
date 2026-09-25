import SwiftUI

struct BatteryGlyph: View {
    let snapshot: BatterySnapshot
    let compact: Bool

    var body: some View {
        HStack(spacing: 3) {
            Text("\(snapshot.percent)%")
                .font(.system(size: compact ? 11 : 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Image(systemName: symbol)
                .font(.system(size: compact ? 12 : 15))
        }
        .foregroundStyle(color)
    }

    private var color: Color {
        if snapshot.isCharging { return .green }
        if snapshot.percent <= 20 { return .red }
        return .white
    }

    private var symbol: String {
        if snapshot.isCharging { return "battery.100percent.bolt" }
        switch snapshot.percent {
        case ..<13: return "battery.0percent"
        case ..<38: return "battery.25percent"
        case ..<63: return "battery.50percent"
        case ..<88: return "battery.75percent"
        default: return "battery.100percent"
        }
    }
}
