import SwiftUI

/// What a wing shows when no HUD claims it: the items the layout puts there, in order.
struct ClosedWing: View {
    static let focusWidth: CGFloat = 14

    let side: HUDWing.Side
    let layout: IslandLayout
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var privacy: PrivacyMonitor
    @EnvironmentObject private var focus: FocusMonitor
    @EnvironmentObject private var bluetooth: BluetoothMonitor
    @EnvironmentObject private var network: NetworkMonitor
    @EnvironmentObject private var volume: VolumeMonitor
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var plugins: PluginRegistry

    /// The ZStack keeps the wing a real, framed view even when it has nothing to show.
    var body: some View {
        ZStack {
            row(side == .leading ? layout.wings.left : layout.wings.right)
        }
        .animation(IslandAnimation.value, value: layout)
    }

    private func row(_ items: [WingItem]) -> some View {
        let visible = layout.visibleItems(items)
        return HStack(spacing: 0) {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, item in
                if index > 0 { WingGapView(gap: layout.wings.gap(between: visible[index - 1], and: item)) }
                badge(for: item)
            }
        }
    }

    @ViewBuilder
    private func badge(for item: WingItem) -> some View {
        switch item {
        case .calendar:
            if layout.showsCalendar, let event = calendar.next { CalendarBadge(event: event) }
        case .privacy:
            if layout.privacyDots > 0 { PrivacyDots(use: privacy.use) }
        case .focus:
            if layout.showsFocus {
                Image(systemName: "moon.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(.indigo)
            }
        case .headphones:
            if layout.showsHeadphones, let device = bluetooth.headphones { HeadphonesBadge(device: device) }
        case .music:
            if let track = nowPlaying.track {
                HStack(spacing: IslandLayout.partGap) {
                    ArtworkView(image: track.artwork, size: layout.artworkSize)
                    AudioBars(isPlaying: nowPlaying.isPlaying, colors: track.barColors)
                }
            }
        case .wifi:
            WiFiBadge(link: network.link, signal: network.signal)
        case .bluetooth:
            if layout.bluetoothOn { BluetoothBadge(connected: !bluetooth.connected.isEmpty) }
        case .volume:
            VolumeBadge(level: volume.level, muted: volume.isMuted)
        case .battery:
            if layout.hasBattery { BatteryBadge(snapshot: battery.snapshot) }
        case .plugin(let id):
            if let plugin = plugins.plugin(id) { PluginWing(plugin: plugin) }
        }
    }
}
