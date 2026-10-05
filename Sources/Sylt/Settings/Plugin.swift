import SwiftUI

enum Plugin: String, CaseIterable, Identifiable, Codable {
    case battery
    case volume
    case brightness
    case nowPlaying
    case notifications
    case bluetooth
    case network
    case calendar
    case keyboard
    case focus
    case privacy
    case thermals

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: "Battery"
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .nowPlaying: "Now Playing"
        case .notifications: "Notifications"
        case .bluetooth: "Bluetooth"
        case .network: "Network"
        case .calendar: "Calendar"
        case .keyboard: "Keyboard"
        case .focus: "Focus"
        case .privacy: "Mic & camera"
        case .thermals: "Thermals"
        }
    }

    var detail: String {
        switch self {
        case .battery: "Alerts at 80, 60, 40, 20, 15, 10, 5 and 0 percent, and when the charger changes."
        case .volume: "Volume overlay and slider."
        case .brightness: "Brightness overlay and slider."
        case .nowPlaying: "Artwork, playback controls and track changes."
        case .notifications: "Mirror Notification Center banners in the island. Experimental, needs Accessibility."
        case .bluetooth: "Devices connecting and disconnecting, their battery, and a warning when it runs low."
        case .network: "Wi-Fi, Ethernet and offline changes."
        case .calendar: "Your next event, a reminder five minutes before, and a join button for video calls."
        case .keyboard: "Caps Lock and keyboard layout changes."
        case .focus: "The active Focus mode."
        case .privacy: "A dot while the microphone or camera is in use."
        case .thermals: "A warning when the Mac gets hot enough to throttle."
        }
    }

    var symbol: String {
        switch self {
        case .battery: "battery.75percent"
        case .volume: "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        case .nowPlaying: "music.note"
        case .notifications: "bell.badge.fill"
        case .bluetooth: "wave.3.right.circle.fill"
        case .network: "wifi"
        case .calendar: "calendar"
        case .keyboard: "keyboard.fill"
        case .focus: "moon.fill"
        case .privacy: "mic.fill"
        case .thermals: "flame.fill"
        }
    }

    /// The colour of its icon tile, one per kind of thing, as System Settings does it.
    var tint: Color {
        switch self {
        case .battery: .green
        case .volume: .pink
        case .brightness: .yellow
        case .nowPlaying: .red
        case .notifications: .gray
        case .bluetooth: .blue
        case .network: .cyan
        case .calendar: .orange
        case .keyboard: .indigo
        case .focus: .purple
        case .privacy: .orange
        case .thermals: .red
        }
    }

    static let defaultEnabled: Set<Plugin> = [
        .battery, .volume, .brightness, .nowPlaying, .bluetooth, .network, .calendar, .keyboard, .focus, .privacy, .thermals,
    ]
}
