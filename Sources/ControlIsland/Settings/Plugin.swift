enum Plugin: String, CaseIterable, Identifiable, Codable {
    case battery
    case volume
    case brightness
    case nowPlaying
    case herdr
    case notifications
    case bluetooth
    case network
    case calendar
    case timer
    case keyboard
    case focus
    case privacy
    case downloads
    case weather
    case thermals
    case shelf
    case clipboard

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: "Battery"
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .nowPlaying: "Now Playing"
        case .herdr: "Agents"
        case .notifications: "Notifications"
        case .bluetooth: "Bluetooth"
        case .network: "Network"
        case .calendar: "Calendar"
        case .timer: "Timer"
        case .keyboard: "Keyboard"
        case .focus: "Focus"
        case .privacy: "Mic & camera"
        case .downloads: "Downloads"
        case .weather: "Weather"
        case .thermals: "Thermals"
        case .shelf: "File shelf"
        case .clipboard: "Clipboard"
        }
    }

    var detail: String {
        switch self {
        case .battery: "Alerts at 80, 60, 40, 20, 15, 10, 5 and 0 percent, and when the charger changes."
        case .volume: "Volume overlay and slider."
        case .brightness: "Brightness overlay and slider."
        case .nowPlaying: "Artwork, playback controls and track changes."
        case .herdr: "Coding agents from Herdr, or found by process when Herdr isn't installed."
        case .notifications: "Mirror Notification Center banners in the island. Experimental, needs Accessibility."
        case .bluetooth: "Devices connecting and disconnecting, their battery, and a warning when it runs low."
        case .network: "Wi-Fi, Ethernet and offline changes."
        case .calendar: "Your next event, a reminder five minutes before, and a join button for video calls."
        case .timer: "Countdowns started from the island, with a chime when they end."
        case .keyboard: "Caps Lock and keyboard layout changes."
        case .focus: "The active Focus mode."
        case .privacy: "A dot while the microphone or camera is in use."
        case .downloads: "Browser downloads starting and finishing."
        case .weather: "Current conditions where the Mac is, from Open-Meteo."
        case .thermals: "A warning when the Mac gets hot enough to throttle."
        case .shelf: "Drop files on the island to keep them handy, drag them out later."
        case .clipboard: "The last few things you copied, one click to copy again."
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
        case .calendar: "calendar"
        case .timer: "timer"
        case .keyboard: "keyboard.fill"
        case .focus: "moon.fill"
        case .privacy: "mic.fill"
        case .downloads: "arrow.down.circle.fill"
        case .weather: "cloud.sun.fill"
        case .thermals: "flame.fill"
        case .shelf: "tray.full.fill"
        case .clipboard: "doc.on.clipboard.fill"
        }
    }

    static let defaultEnabled: Set<Plugin> = [
        .battery, .volume, .brightness, .nowPlaying, .bluetooth, .network,
        .calendar, .timer, .keyboard, .focus, .privacy, .downloads, .weather, .thermals, .shelf,
    ]
}
