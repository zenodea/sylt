enum Plugin: String, CaseIterable, Identifiable, Codable {
    case battery
    case volume
    case brightness
    case nowPlaying
    case herdr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .battery: "Battery"
        case .volume: "Volume"
        case .brightness: "Brightness"
        case .nowPlaying: "Now Playing"
        case .herdr: "Herdr"
        }
    }

    var detail: String {
        switch self {
        case .battery: "Alerts at 80, 60, 40, 20, 15, 10, 5 and 0 percent, and when the charger changes."
        case .volume: "Volume overlay and slider."
        case .brightness: "Brightness overlay and slider."
        case .nowPlaying: "Artwork, playback controls and track changes."
        case .herdr: "Agent status for the Herdr terminal workspace manager."
        }
    }

    var symbol: String {
        switch self {
        case .battery: "battery.75percent"
        case .volume: "speaker.wave.2.fill"
        case .brightness: "sun.max.fill"
        case .nowPlaying: "music.note"
        case .herdr: "terminal.fill"
        }
    }

    static let defaultEnabled: Set<Plugin> = [.battery, .volume, .brightness, .nowPlaying]
}
