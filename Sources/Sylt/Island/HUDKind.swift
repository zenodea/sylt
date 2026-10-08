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
        /// Content lives in the wings, island stays at notch height. A nil
        /// side is left to its closed content.
        case compact(leading: Double?, trailing: Double?)
        /// The closed wings as they are, plus one text row under the notch.
        case twoRow
        /// A card that drops below the notch.
        case card

        /// Whether the island keeps its wings view, so unclaimed wings never change.
        var keepsWings: Bool {
            if case .card = self { return false }
            return true
        }
    }

    /// Wings fit what they hold, measured; a family with several labels takes
    /// its widest so the island never resizes between them.
    var style: Style {
        switch self {
        case .volume, .brightness, .mute: .compact(leading: nil, trailing: Self.wing(Self.glyphWidth + Self.glyphGap + Self.levelWidth))
        case .battery: .compact(leading: Self.wing(48), trailing: Self.wing(Self.text(Self.batteryMessages)))
        case .unlocked: .compact(leading: LockedView.leadingWing, trailing: LockedView.greetingWing)
        case .nowPlaying, .notification: .twoRow
        case .bluetooth(let event): Self.glyph(trailing: Self.device(event.device))
        case .peripheralBattery(let device): Self.glyph(trailing: Self.device(device))
        case .network: Self.glyph(trailing: Self.text(NetworkMonitor.Link.allCases.map(\.title)))
        case .calendar(let event): Self.glyph(trailing: min(Self.text(event.title), 150) + 6 + Self.text("in 30m"))
        case .focus(let mode): Self.glyph(trailing: Self.text(mode ?? "Focus off"))
        case .privacy: Self.glyph(trailing: Self.text(Self.privacyMessages))
        case .thermal(let state): Self.glyph(trailing: Self.text(state == .nominal ? "Cooled down" : "\(state.title) · performance reduced"))
        case .capsLock: .compact(leading: nil, trailing: Self.wing(Self.glyphWidth + Self.glyphGap + Self.text(["Caps Lock on", "Caps Lock off"])))
        case .inputSource(let name): .compact(leading: nil, trailing: Self.wing(Self.glyphWidth + Self.glyphGap + min(Self.text(name), 140)))
        case .external(let hud): hud.style
        }
    }

    /// Mute and volume are one wing that morphs; everything else replaces its wing.
    var wingIdentity: HUDKind {
        if case .mute = self { return .volume }
        return self
    }

    static let batteryMessages = ["Charging", "On battery", "Fully charged", "Critically low", "Low battery", "Battery"]
    static let privacyMessages = ["Mic and camera on", "Microphone on", "Camera on", "Mic and camera off"]

    /// A symbol in a wing, the gap after it, a level bar, and the wing a leading symbol alone takes.
    static let glyphWidth: CGFloat = 16
    static let glyphGap: CGFloat = 8
    static let levelWidth: CGFloat = 72
    static let glyphWing = wing(18)

    /// A wing just wide enough for this content, with the usual room either side of it.
    static func wing(_ content: CGFloat) -> Double {
        content + IslandLayout.notchGap + IslandLayout.wingEdge
    }

    private static func glyph(trailing: CGFloat) -> Style {
        .compact(leading: glyphWing, trailing: wing(trailing))
    }

    private static func text(_ text: String) -> CGFloat { TextWidth.of(text, size: 11) }
    private static func text(_ texts: [String]) -> CGFloat { TextWidth.widest(texts, size: 11) }

    private static func device(_ device: BluetoothMonitor.Device) -> CGFloat {
        min(text(device.name), 110) + (device.battery == nil ? 0 : 8 + DeviceBattery.width)
    }

    var category: HUDCategory {
        switch self {
        case .volume: .volume
        case .brightness: .brightness
        case .battery: .battery
        case .nowPlaying: .nowPlaying
        case .unlocked: .unlock
        case .notification: .notifications
        case .mute: .volume
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
        case .volume, .brightness: 1
        case .battery: 1.5
        case .unlocked: 1.4
        case .nowPlaying: 2.2
        case .notification: 3
        case .mute: 1
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

/// A plugin's HUD, with the plugin that asked for it and a unique identity so a repeat shows again.
struct ExternalHUD: Hashable {
    let pluginID: String
    let hud: PluginHUD
    let id = UUID()

    var hasGlyph: Bool { hud.symbol != nil || hud.image != nil }

    var content: CGFloat {
        (hud.level != nil ? HUDKind.levelWidth : min(TextWidth.of(hud.text ?? "", size: 11), 160)) + (hud.trailingSymbol == nil ? 0 : HUDKind.glyphGap + HUDKind.glyphWidth)
    }

    var style: HUDKind.Style {
        switch hud.side {
        case "right": .compact(leading: nil, trailing: HUDKind.wing((hasGlyph ? HUDKind.glyphWidth + HUDKind.glyphGap : 0) + content))
        case "left": .compact(leading: HUDKind.wing(content + (hasGlyph ? HUDKind.glyphWidth + 6 : 0)), trailing: nil)
        default: .compact(leading: hasGlyph ? HUDKind.glyphWing : nil, trailing: HUDKind.wing(content))
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

extension NetworkMonitor.Link {
    var title: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .ethernet: "Ethernet"
        case .other: "Online"
        case .offline: "Offline"
        }
    }
}
