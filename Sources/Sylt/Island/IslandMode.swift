enum IslandMode: Hashable {
    case closed
    case locked
    case hud(HUDKind)
    case expanded

    var contentIdentity: IslandMode {
        switch self {
        case .hud(.unlocked): .locked
        case .hud(let kind) where kind.style.keepsWings: .closed
        default: self
        }
    }
}
