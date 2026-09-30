enum Plugin: String, CaseIterable, Identifiable, Codable {
    case battery
    case volume
    case brightness
    case nowPlaying
    case herdr
    case notifications
    case bluetooth
    case network

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: "Battery"
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .nowPlaying: "Now Playing"
        case .herdr: "Herdr"
        case .notifications: "Notifications"
        case .bluetooth: "Bluetooth"
        case .network: "Network"
        }
    }

    var detail: String {
        switch self {
        case .battery: "Alerts at 80, 60, 40, 20, 15, 10, 5 and 0 percent, and when the charger changes."
        case .volume: "Volume overlay and slider."
        case .brightness: "Brightness overlay and slider."
        case .nowPlaying: "Artwork, playback controls and track changes."
        case .herdr: "Agent status for the Herdr terminal workspace manager."
        case .notifications: "Mirror Notification Center banners in the island. Experimental, needs Accessibility."
        case .bluetooth: "Devices connecting and disconnecting, with their battery."
        case .network: "Wi-Fi, Ethernet and offline changes."
        }
    }

    var symbol: String {
        switch self {
        case .battery: "battery.75percent"
        case .volume: "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        case .nowPlaying: "music.note"
        case .herdr: "terminal.fill"
        case .notifications: "bell.badge.fill"
        case .bluetooth: "wave.3.right.circle.fill"
        case .network: "wifi"
        }
    }

    static let defaultEnabled: Set<Plugin> = [.battery, .volume, .brightness, .nowPlaying, .bluetooth, .network]
}
