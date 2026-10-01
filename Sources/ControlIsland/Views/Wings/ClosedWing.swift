import SwiftUI

/// What a wing shows when no HUD claims it: agents, the next event and a
/// running timer on the left; privacy dots, Focus, headphones, weather and
/// music on the right.
struct ClosedWing: View {
    let side: HUDWing.Side
    let layout: IslandLayout
    @EnvironmentObject private var herdr: HerdrMonitor
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var timer: TimerMonitor
    @EnvironmentObject private var privacy: PrivacyMonitor
    @EnvironmentObject private var focus: FocusMonitor
    @EnvironmentObject private var bluetooth: BluetoothMonitor
    @EnvironmentObject private var weather: WeatherMonitor

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
            if layout.showsAgents { AgentStack(agents: herdr.agents) }
            if layout.showsCalendar, let event = calendar.next { CalendarBadge(event: event) }
            if layout.showsTimer { TimerBadge(timer: timer) }
        }
    }

    private var trailing: some View {
        HStack(spacing: 8) {
            if layout.privacyDots > 0 { PrivacyDots(use: privacy.use) }
            if layout.showsFocus {
                Image(systemName: "moon.fill").font(.system(size: 11, weight: .semibold)).foregroundStyle(.indigo)
            }
            if layout.showsHeadphones, let device = bluetooth.headphones { HeadphonesBadge(device: device) }
            if layout.showsWeather, let report = weather.report { WeatherBadge(report: report) }
            if let track = nowPlaying.track {
                ArtworkView(image: track.artwork, size: layout.artworkSize)
                AudioBars(isPlaying: nowPlaying.isPlaying, colors: track.barColors)
            }
        }
    }
}
