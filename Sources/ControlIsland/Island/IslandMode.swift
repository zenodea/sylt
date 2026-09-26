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

    var isWide: Bool {
        switch self {
        case .nowPlaying, .agentFinished: true
        default: false
        }
    }
}
