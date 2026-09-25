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
    case battery
}
