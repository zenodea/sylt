import SwiftUI

/// What a wing shows when no HUD claims it: the items the layout puts there, in order.
struct ClosedWing: View {
    let side: HUDWing.Side
    let layout: IslandLayout
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var privacy: PrivacyMonitor
    @EnvironmentObject private var focus: FocusMonitor
    @EnvironmentObject private var bluetooth: BluetoothMonitor
    @EnvironmentObject private var plugins: PluginRegistry

    var body: some View {
        // A ZStack keeps the wing a real, framed view even when it has nothing to show.
        ZStack {
            switch side {
            case .leading: leading
            case .trailing: trailing
            }
        }
        .animation(IslandAnimation.value, value: layout)
    }

    private var leading: some View {
        HStack(spacing: 8) {
            ForEach(layout.wings.left, id: \.id) { item in badge(for: item) }
        }
    }

    private var trailing: some View {
        HStack(spacing: 8) {
            ForEach(layout.wings.right, id: \.id) { item in badge(for: item) }
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
                ArtworkView(image: track.artwork, size: layout.artworkSize)
                AudioBars(isPlaying: nowPlaying.isPlaying, colors: track.barColors)
            }
        case .plugin(let id):
            if let plugin = plugins.plugins.first(where: { $0.id == id }) { PluginWing(plugin: plugin) }
        }
    }
}
