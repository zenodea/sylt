enum IslandMode: Hashable {
    case closed
    case peek
    case hud(HUDKind)
    case expanded

    var showsClosedContent: Bool {
        switch self {
        case .closed, .peek: true
        default: false
        }
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

    enum Style: Hashable {
        /// Content lives in the wings, island stays at notch height.
        case compact(leading: Double, trailing: Double)
        /// Wings plus one text row under the notch.
        case twoRow(wing: Double)
        /// A card that drops below the notch.
        case card(width: Double)
    }

    var style: Style {
        switch self {
        case .volume, .brightness: .compact(leading: 34, trailing: 92)
        case .battery: .compact(leading: 62, trailing: 96)
        case .agentFinished: .compact(leading: 190, trailing: 0)
        case .unlocked: .compact(leading: 34, trailing: 136)
        case .nowPlaying: .twoRow(wing: 44)
        case .notification: .card(width: 140)
        }
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
        }
    }
}

enum HUDCategory: String, CaseIterable, Identifiable, Codable {
    case volume, brightness, battery, nowPlaying, herdr, unlock, notifications

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
        }
    }
}
