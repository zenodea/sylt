import SwiftUI

/// What a wing shows when no HUD claims it: the next event and plugin badges
/// on the left; privacy dots, Focus, headphones, music and plugin badges on the right.
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
            if layout.showsCalendar, let event = calendar.next { CalendarBadge(event: event) }
            ForEach(plugins.plugins) { plugin in PluginWing(plugin: plugin, side: .leading) }
        }
    }

    private var trailing: some View {
        HStack(spacing: 8) {
            if layout.privacyDots > 0 { PrivacyDots(use: privacy.use) }
            if layout.showsFocus {
                Image(systemName: "moon.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(.indigo)
            }
            if layout.showsHeadphones, let device = bluetooth.headphones { HeadphonesBadge(device: device) }
            ForEach(plugins.plugins) { plugin in PluginWing(plugin: plugin, side: .trailing) }
            if let track = nowPlaying.track {
                ArtworkView(image: track.artwork, size: layout.artworkSize)
                AudioBars(isPlaying: nowPlaying.isPlaying, colors: track.barColors)
            }
        }
    }
}
