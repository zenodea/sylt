import SwiftUI

struct HUDView: View {
    let kind: HUDKind
    let layout: IslandLayout
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var volume: VolumeMonitor
    @EnvironmentObject private var brightness: BrightnessMonitor
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var herdr: HerdrMonitor

    var body: some View {
        Group {
            switch kind.style {
            case .compact(let leading, let trailing): wings(leading: leading, trailing: trailing)
            case .twoRow(let wing): VStack(spacing: 0) { wings(leading: wing, trailing: wing); row }
            case .card: card
            }
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
    }

    /// Content hugs the notch; the slack sits at the island's outer ends.
    private func wings(leading leadingWidth: Double, trailing trailingWidth: Double) -> some View {
        let gap = IslandLayout.notchGap
        return HStack(spacing: 0) {
            leading
                .frame(width: max(0, leadingWidth - gap), alignment: .trailing)
                .padding(.trailing, leadingWidth > 0 ? gap : 0)
            Spacer().frame(width: layout.notchWidth)
            trailing
                .frame(width: max(0, trailingWidth - gap), alignment: .leading)
                .padding(.leading, trailingWidth > 0 ? gap : 0)
        }
        .frame(height: layout.notchHeight + 2)
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
    }

    @ViewBuilder
    private var leading: some View {
        switch kind {
        case .battery: BatteryGlyph(snapshot: battery.snapshot, compact: true)
        case .agentFinished(let agent):
            HStack(spacing: 6) {
                HarnessIcon(harness: agent.harness, size: 16)
                Text(agent.title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .truncationMode(.tail)
                DoneMark()
            }
            .padding(.leading, IslandLayout.wingEdge)
        case .nowPlaying:
            if let track = nowPlaying.track { ArtworkView(image: track.artwork, size: layout.artworkSize) }
        case .bluetooth(let event):
            if case .connected = event { BluetoothGlyph(connected: true) } else { BluetoothGlyph(connected: false) }
        case .network(let link): NetworkGlyph(link: link)
        case .volume, .brightness, .mute, .notification, .unlocked: EmptyView()
        }
    }

    @ViewBuilder
    private var trailing: some View {
        switch kind {
        case .volume:
            level(Image(systemName: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill"), volume.isMuted ? 0 : Double(volume.level))
        case .brightness: level(Image(systemName: "sun.max.fill"), Double(brightness.level))
        case .mute(let muted): level(MuteGlyph(muted: muted), muted ? 0 : Double(volume.level))
        case .battery(let alert):
            Text(alert.message(onAC: battery.snapshot.onAC))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(batteryColor(alert))
                .lineLimit(1)
        case .nowPlaying:
            if let track = nowPlaying.track { AudioBars(isPlaying: nowPlaying.isPlaying, colors: track.barColors) }
        case .bluetooth(let event): bluetooth(event)
        case .network(let link):
            Text(link.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(link == .offline ? Color.white.opacity(0.6) : .white)
        case .agentFinished, .notification, .unlocked: EmptyView()
        }
    }

    private func level(_ glyph: some View, _ value: Double) -> some View {
        HStack(spacing: 8) {
            glyph.frame(width: 16)
            LevelBar(value: value)
        }
        .padding(.trailing, IslandLayout.wingEdge)
    }

    private func bluetooth(_ event: BluetoothMonitor.Event) -> some View {
        let device: BluetoothMonitor.Device
        switch event {
        case .connected(let connected): device = connected
        case .disconnected(let disconnected): device = disconnected
        }
        return HStack(spacing: 8) {
            Text(device.name)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(device.battery == nil ? 0.6 : 1)
            if let battery = device.battery {
                DeviceBattery(percent: battery)
            }
        }
        .padding(.trailing, IslandLayout.wingEdge)
    }

    @ViewBuilder
    private var row: some View {
        if let track = nowPlaying.track {
            MarqueeText(text: track.artist.isEmpty ? track.title : "\(track.title)  ·  \(track.artist)")
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: IslandLayout.hudRowHeight)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var card: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: layout.notchHeight - 4)
            if case .notification(let notification) = kind {
                HStack(spacing: 10) {
                    if let icon = notification.icon {
                        Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "bell.fill").frame(width: 28, height: 28)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(notification.title).lineLimit(1)
                        Text(notification.body).lineLimit(1)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func tapped() {
        if case .agentFinished(let agent) = kind { herdr.focus(agent) }
    }

    private func batteryColor(_ alert: BatteryAlert) -> Color {
        if case .level(let percent) = alert, percent <= 20 { return .red }
        return .white.opacity(0.8)
    }
}
