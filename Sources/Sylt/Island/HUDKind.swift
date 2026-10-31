import CoreGraphics
import Foundation

enum HUDKind: Hashable {
    case volume
    case brightness
    case battery(BatteryAlert)
    case nowPlaying
    case unlocked
    case notification(SystemNotification)
    case mute(Bool)
    case bluetooth(BluetoothMonitor.Event)
    case network(NetworkMonitor.Link)
    case peripheralBattery(BluetoothMonitor.Device)
    case calendar(CalendarMonitor.Event)
    case capsLock(Bool)
    case inputSource(String)
    case focus(String?)
    case privacy(PrivacyMonitor.Use)
    case thermal(ProcessInfo.ThermalState)
    case external(ExternalHUD)

    enum Style: Hashable {
        case compact(leading: Double?, trailing: Double?)
        case twoRow
        case card

        var keepsWings: Bool {
            if case .card = self { return false }
            return true
        }
    }

    var style: Style {
        switch self {
        case .volume, .brightness, .mute: Self.trailingGlyph(beside: Self.levelWidth)
        case .battery: .compact(leading: Self.wing(48), trailing: Self.wing(Self.text(Self.batteryMessages)))
        case .unlocked: .compact(leading: LockedView.leadingWing, trailing: LockedView.greetingWing)
        case .nowPlaying, .notification: .twoRow
        case .bluetooth(let event): Self.glyph(trailing: Self.device(event.device))
        case .peripheralBattery(let device): Self.glyph(trailing: Self.device(device))
        case .network: Self.glyph(trailing: Self.text(NetworkMonitor.Link.allCases.map(\.title)))
        case .calendar(let event): Self.glyph(trailing: min(Self.text(event.title), 150) + 6 + Self.text("in 30m"))
        case .focus, .privacy, .thermal: Self.glyph(trailing: Self.text(text ?? ""))
        case .capsLock: Self.trailingGlyph(beside: Self.text(Self.capsLockTexts))
        case .inputSource(let name): Self.trailingGlyph(beside: min(Self.text(name), 140))
        case .external(let hud): hud.style
        }
    }

    var text: String? {
        switch self {
        case .focus(let mode): mode ?? "Focus off"
        case .privacy(let use): use.message
        case .thermal(let state): state == .nominal ? "Cooled down" : "\(state.title) · performance reduced"
        case .capsLock(let on): Self.capsLockTexts[on ? 0 : 1]
        default: nil
        }
    }

    private static let capsLockTexts = ["Caps Lock on", "Caps Lock off"]

    var wingIdentity: HUDKind {
        if case .mute = self { return .volume }
        return self
    }

    static let batteryMessages = ["Charging", "On battery", "Fully charged", "Critically low", "Low battery", "Battery"]

    static let glyphWidth: CGFloat = 16
    static let glyphGap: CGFloat = 8
    static let levelWidth: CGFloat = 72
    static let glyphWing = wing(18)

    static func wing(_ content: CGFloat) -> Double {
        content + IslandLayout.notchGap + IslandLayout.wingEdge
    }

    private static func glyph(trailing: CGFloat) -> Style {
        .compact(leading: glyphWing, trailing: wing(trailing))
    }

    private static func trailingGlyph(beside content: CGFloat) -> Style {
        .compact(leading: nil, trailing: wing(glyphWidth + glyphGap + content))
    }

    fileprivate static func text(_ text: String) -> CGFloat { TextWidth.of(text, size: 11) }
    private static func text(_ texts: [String]) -> CGFloat { TextWidth.widest(texts, size: 11) }

    private static func device(_ device: BluetoothMonitor.Device) -> CGFloat {
        text(device.name) + (device.battery == nil ? 0 : 8 + DeviceBattery.width)
    }

    var category: HUDCategory {
        switch self {
        case .volume, .mute: .volume
        case .brightness: .brightness
        case .battery: .battery
        case .nowPlaying: .nowPlaying
        case .unlocked: .unlock
        case .notification: .notifications
        case .bluetooth, .peripheralBattery: .bluetooth
        case .network: .network
        case .calendar: .calendar
        case .capsLock, .inputSource: .keyboard
        case .focus: .focus
        case .privacy: .privacy
        case .thermal: .thermals
        case .external: .plugins
        }
    }

    var duration: Double {
        switch self {
        case .volume, .brightness, .mute: 1
        case .battery: 1.5
        case .unlocked: 1.4
        case .nowPlaying: 2.2
        case .notification: 3
        case .bluetooth, .peripheralBattery: 2.4
        case .network: 1.8
        case .calendar: 4
        case .capsLock: 0.9
        case .inputSource: 1.2
        case .focus: 1.8
        case .privacy: 1.6
        case .thermal: 2.5
        case .external(let hud): hud.hud.duration ?? 2
        }
    }
}

struct ExternalHUD: Hashable {
    let pluginID: String
    let hud: PluginHUD
    // Unique, so a repeat of the same HUD still shows again.
    let id = UUID()

    var hasGlyph: Bool { hud.symbol != nil || hud.image != nil }
    var side: HUDSide { hud.side ?? .both }

    var content: CGFloat {
        let main = hud.level != nil ? HUDKind.levelWidth : min(HUDKind.text(hud.text ?? ""), 160)
        return main + (hud.trailingSymbol == nil ? 0 : HUDKind.glyphGap + HUDKind.glyphWidth)
    }

    var style: HUDKind.Style {
        let withGlyph = HUDKind.wing((hasGlyph ? HUDKind.glyphWidth + HUDKind.glyphGap : 0) + content)
        return switch side {
        case .right: .compact(leading: nil, trailing: withGlyph)
        case .left: .compact(leading: withGlyph, trailing: nil)
        case .both: .compact(leading: hasGlyph ? HUDKind.glyphWing : nil, trailing: HUDKind.wing(content))
        }
    }
}

enum HUDCategory: String, CaseIterable, Identifiable, Codable {
    case volume, brightness, battery, nowPlaying, unlock, notifications, bluetooth, network
    case calendar, keyboard, focus, privacy, thermals, plugins

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .battery: "Battery alerts"
        case .nowPlaying: "Track changes"
        case .unlock: "Unlock"
        case .notifications: "Notifications"
        case .bluetooth: "Bluetooth"
        case .network: "Network"
        case .calendar: "Calendar reminders"
        case .keyboard: "Caps Lock and layout"
        case .focus: "Focus changes"
        case .privacy: "Mic and camera"
        case .thermals: "Thermals"
        case .plugins: "Plugins"
        }
    }

    var symbol: String {
        switch self {
        case .volume: "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        case .battery: "battery.75percent"
        case .nowPlaying: "music.note"
        case .unlock: "lock.open.fill"
        case .notifications: "bell.fill"
        case .bluetooth: "dot.radiowaves.left.and.right"
        case .network: "wifi"
        case .calendar: "calendar"
        case .keyboard: "keyboard.fill"
        case .focus: "moon.fill"
        case .privacy: "mic.fill"
        case .thermals: "flame.fill"
        case .plugins: "puzzlepiece.extension.fill"
        }
    }
}
