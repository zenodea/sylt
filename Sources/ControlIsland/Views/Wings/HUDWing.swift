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
        case .bluetooth(let event):
            if case .connected = event { BluetoothGlyph(connected: true) } else { BluetoothGlyph(connected: false) }
        case .network(let link): NetworkGlyph(link: link)
        case .peripheralBattery: HUDGlyph(symbol: "battery.25percent", tint: .red)
        case .calendar: HUDGlyph(symbol: "calendar", tint: .orange)
        case .focus(let mode): HUDGlyph(symbol: mode == nil ? "moon" : "moon.fill", tint: mode == nil ? .white.opacity(0.6) : .indigo)
        case .privacy(let use): PrivacyDots(use: use)
        case .thermal(let state): HUDGlyph(symbol: state == .nominal ? "snowflake" : "flame.fill", tint: state == .nominal ? .cyan : .orange)
        case .external(let external):
            switch external.hud.side {
            case "left": externalContent(external, leadingGlyph: true).padding(.leading, IslandLayout.wingEdge)
            case "right": EmptyView()
            default: externalGlyph(external)
            }
        case .volume, .brightness, .mute, .nowPlaying, .notification, .unlocked, .capsLock, .inputSource: EmptyView()
        }
    }

    @ViewBuilder
    private var trailing: some View {
        if let muted = mutedState {
            // One view for mute and volume, so the bar slides and the speaker morphs between them.
            level(MuteGlyph(muted: muted), muted ? 0 : Double(volume.level))
        } else {
            trailingSwitch
        }
    }

    private var mutedState: Bool? {
        switch kind {
        case .volume: volume.isMuted
        case .mute(let muted): muted
        default: nil
        }
    }

    @ViewBuilder
    private var trailingSwitch: some View {
        switch kind {
        case .volume, .mute: EmptyView()
        case .brightness: level(Image(systemName: "sun.max.fill"), Double(brightness.level))
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
        case .capsLock(let on): rightOnly("capslock.fill", on ? "Caps Lock on" : "Caps Lock off", dimmed: !on)
        case .inputSource(let name): rightOnly("keyboard.fill", name)
        case .focus(let mode): HUDLabel(text: mode ?? "Focus off", dimmed: mode == nil)
        case .privacy(let use): HUDLabel(text: Self.privacyText(use), dimmed: !use.any)
        case .thermal(let state): HUDLabel(text: state == .nominal ? "Cooled down" : "\(state.title) · performance reduced")
        case .external(let external):
            switch external.hud.side {
            case "right": externalContent(external, leadingGlyph: true).padding(.trailing, IslandLayout.wingEdge)
            case "left": EmptyView()
            default: externalContent(external, leadingGlyph: false).padding(.trailing, IslandLayout.wingEdge)
            }
        case .nowPlaying, .notification, .unlocked: EmptyView()
        }
    }

    private func externalGlyph(_ external: ExternalHUD) -> some View {
        PluginGlyph(symbol: external.hud.symbol, image: external.hud.image, tint: external.hud.tint, size: 16)
            .symbolEffect(.bounce, options: .nonRepeating, value: external.id)
    }

    private func externalContent(_ external: ExternalHUD, leadingGlyph: Bool) -> some View {
        HStack(spacing: 8) {
            if leadingGlyph, external.hasGlyph { externalGlyph(external).frame(width: 16) }
            if let level = external.hud.level {
                LevelBar(value: level)
            } else {
                HUDLabel(text: external.hud.text ?? "")
            }
            if let symbol = external.hud.trailingSymbol {
                PopGlyph(symbol: symbol, tint: Color(tint: external.hud.trailingTint ?? "green"))
            }
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
