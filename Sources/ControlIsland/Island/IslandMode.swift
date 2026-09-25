enum IslandMode: Hashable {
    case closed
    case hud(HUDKind)
    case expanded
}

enum HUDKind: Hashable {
    case volume
    case battery
}
