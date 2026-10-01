import SwiftUI

/// One side of a HUD.
struct HUDWing: View {
    enum Side { case leading, trailing }

    let kind: HUDKind
    let side: Side
    let layout: IslandLayout
    @EnvironmentObject private var battery: BatteryMonitor
    @EnvironmentObject private var volume: VolumeMonitor
    @EnvironmentObject private var brightness: BrightnessMonitor
    @EnvironmentObject private var herdr: HerdrMonitor

    var body: some View {
        switch side {
        case .leading: leading
        case .trailing: trailing
        }
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
            .contentShape(Rectangle())
            .onTapGesture { herdr.focus(agent) }
        case .bluetooth(let event):
            if case .connected = event { BluetoothGlyph(connected: true) } else { BluetoothGlyph(connected: false) }
        case .network(let link): NetworkGlyph(link: link)
        case .peripheralBattery: HUDGlyph(symbol: "battery.25percent", tint: .red)
        case .calendar: HUDGlyph(symbol: "calendar", tint: .orange)
        case .timerDone: HUDGlyph(symbol: "timer", tint: .orange, size: 15)
        case .focus(let mode): HUDGlyph(symbol: mode == nil ? "moon" : "moon.fill", tint: mode == nil ? .white.opacity(0.6) : .indigo)
        case .privacy(let use): PrivacyDots(use: use)
        case .download(let event):
            if case .started = event { HUDGlyph(symbol: "arrow.down.circle.fill", tint: .blue) } else { HUDGlyph(symbol: "checkmark.circle.fill", tint: .green) }
        case .thermal(let state): HUDGlyph(symbol: state == .nominal ? "snowflake" : "flame.fill", tint: state == .nominal ? .cyan : .orange)
        case .volume, .brightness, .mute, .nowPlaying, .notification, .unlocked, .capsLock, .inputSource: EmptyView()
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
        case .bluetooth(let event): bluetooth(event)
        case .network(let link):
            Text(link.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(link == .offline ? Color.white.opacity(0.6) : .white)
        case .peripheralBattery(let device): bluetooth(.connected(device))
        case .calendar(let event): calendar(event)
        case .timerDone(let duration): HUDLabel(text: "\(Int(duration / 60)) min timer done")
        case .capsLock(let on): rightOnly("capslock.fill", on ? "Caps Lock on" : "Caps Lock off", dimmed: !on)
        case .inputSource(let name): rightOnly("keyboard.fill", name)
        case .focus(let mode): HUDLabel(text: mode ?? "Focus off", dimmed: mode == nil)
        case .privacy(let use): HUDLabel(text: Self.privacyText(use), dimmed: !use.any)
        case .download(let event): HUDLabel(text: event.name)
        case .thermal(let state): HUDLabel(text: state == .nominal ? "Cooled down" : "\(state.title) · performance reduced")
        case .agentFinished, .nowPlaying, .notification, .unlocked: EmptyView()
        }
    }

    /// Glyph and label on the right, for HUDs that leave the left wing alone.
    private func rightOnly(_ symbol: String, _ text: String, dimmed: Bool = false) -> some View {
        HStack(spacing: 8) {
            HUDGlyph(symbol: symbol, tint: dimmed ? .white.opacity(0.6) : .white).frame(width: 16)
            HUDLabel(text: text, dimmed: dimmed)
        }
    }

    private func calendar(_ event: CalendarMonitor.Event) -> some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 6) {
                HUDLabel(text: event.title).frame(maxWidth: .infinity, alignment: .leading)
                Text(event.start > context.date ? "in \(CalendarBadge.countdown(to: event.start, now: context.date))" : "now")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.orange)
                    .monospacedDigit()
            }
            .padding(.trailing, IslandLayout.wingEdge)
        }
    }

    private static func privacyText(_ use: PrivacyMonitor.Use) -> String {
        switch (use.microphone, use.camera) {
        case (true, true): "Mic and camera on"
        case (true, false): "Microphone on"
        case (false, true): "Camera on"
        case (false, false): "Mic and camera off"
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
                .frame(maxWidth: 110, alignment: .leading)
                .opacity(device.battery == nil ? 0.6 : 1)
            if let battery = device.battery {
                DeviceBattery(percent: battery)
            }
        }
        .padding(.trailing, IslandLayout.wingEdge)
    }

    private func batteryColor(_ alert: BatteryAlert) -> Color {
        if case .level(let percent) = alert, percent <= 20 { return .red }
        return .white.opacity(0.8)
    }
}
