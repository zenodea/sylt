import SwiftUI

/// The menu bar's own items, for an island that stands in for it. Each has a fixed width
/// so the wing never resizes as a reading changes.
struct WiFiBadge: View {
    static let width: CGFloat = 15

    let link: NetworkMonitor.Link
    let signal: Double

    var body: some View {
        Group {
            switch link {
            case .wifi: Image(systemName: "wifi", variableValue: signal)
            case .ethernet: Image(systemName: "cable.connector.horizontal")
            case .other: Image(systemName: "network")
            case .offline: Image(systemName: "wifi.slash")
            }
        }
        .font(.system(size: 12, weight: .semibold))
        .foregroundStyle(.white.opacity(link == .offline ? 0.45 : 0.85))
        .frame(width: Self.width)
        .animation(IslandAnimation.value, value: link)
    }
}

/// The rune drawn to the Wi-Fi symbol's weight and colour, so the two read as a pair.
struct BluetoothBadge: View {
    static let width: CGFloat = 12

    let connected: Bool

    var body: some View {
        RuneMark(color: .white.opacity(connected ? 0.85 : 0.5), lineWidth: 1.6, height: 12)
            .frame(width: Self.width)
            .animation(IslandAnimation.value, value: connected)
    }
}

struct VolumeBadge: View {
    static let width: CGFloat = 17

    let level: Float
    let muted: Bool

    var body: some View {
        Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.3.fill", variableValue: Double(level))
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(.white.opacity(muted ? 0.45 : 0.85))
            .frame(width: Self.width)
            .animation(IslandAnimation.value, value: muted)
    }
}

struct BatteryBadge: View {
    static let width: CGFloat = TextWidth.of("100%", size: 11, monospacedDigits: true) + 3 + 20

    let snapshot: BatterySnapshot

    var body: some View {
        BatteryGlyph(snapshot: snapshot, compact: true)
            .frame(width: Self.width)
    }
}
