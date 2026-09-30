import CoreGraphics

enum IslandMode: Hashable {
    case closed
    case locked
    case hud(HUDKind)
    case expanded

    /// The unlock HUD morphs out of the locked island instead of replacing it.
    var contentIdentity: IslandMode {
        self == .hud(.unlocked) ? .locked : self
    }
}

enum HUDKind: Hashable {
    case volume
    case brightness
    case battery(BatteryAlert)
    case nowPlaying
    case agentFinished(HerdrAgent)
    case unlocked
    case notification(SystemNotification)
    case mute(Bool)
    case bluetooth(BluetoothMonitor.Event)
    case network(NetworkMonitor.Link)

    enum Style: Hashable {
        /// Content lives in the wings, island stays at notch height.
        case compact(leading: Double, trailing: Double)
        /// Wings plus one text row under the notch.
        case twoRow(wing: Double)
        /// A card that drops below the notch.
        case card
    }

    /// Every HUD adds the same `IslandLayout.hudWings` to the notch; a kind only
    /// decides how that budget splits between the two sides.
    var style: Style {
        switch self {
        case .volume, .brightness, .mute: Self.split(leading: 0)
        case .battery: Self.split(leading: Self.wing(48))
        case .agentFinished: Self.split(leading: IslandLayout.hudWings)
        case .unlocked: Self.split(leading: LockedView.leadingWing)
        case .nowPlaying: .twoRow(wing: IslandLayout.hudWings / 2)
        case .notification: .card
        case .bluetooth, .network: Self.split(leading: Self.wing(18))
        }
    }

    static func wing(_ content: CGFloat) -> Double {
        content + IslandLayout.notchGap + IslandLayout.wingEdge
    }

    private static func split(leading: Double) -> Style {
        .compact(leading: leading, trailing: IslandLayout.hudWings - leading)
    }

    var category: HUDCategory {
        switch self {
        case .volume: .volume
        case .brightness: .brightness
        case .battery: .battery
        case .nowPlaying: .nowPlaying
        case .agentFinished: .herdr
        case .unlocked: .unlock
        case .notification: .notifications
        case .mute: .volume
        case .bluetooth: .bluetooth
        case .network: .network
        }
    }

    var duration: Double {
        switch self {
        case .volume, .brightness: 1
        case .battery: 1.5
        case .unlocked: 1.4
        case .nowPlaying: 2.2
        case .agentFinished: 2.5
        case .notification: 3
        case .mute: 1
        case .bluetooth: 2.4
        case .network: 1.8
        }
    }
}

enum HUDCategory: String, CaseIterable, Identifiable, Codable {
    case volume, brightness, battery, nowPlaying, herdr, unlock, notifications, bluetooth, network

    var id: String { rawValue }

    var title: String {
        switch self {
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .battery: "Battery alerts"
        case .nowPlaying: "Track changes"
        case .herdr: "Herdr agents"
        case .unlock: "Unlock"
        case .notifications: "Notifications"
        case .bluetooth: "Bluetooth"
        case .network: "Network"
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
