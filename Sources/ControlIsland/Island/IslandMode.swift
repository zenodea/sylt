import CoreGraphics
import Foundation

enum IslandMode: Hashable {
    case closed
    case locked
    case hud(HUDKind)
    case expanded

    /// Closed and compact HUDs share the wings view, so only the claimed wing
    /// changes; the unlock HUD morphs out of the locked island.
    var contentIdentity: IslandMode {
        switch self {
        case .hud(.unlocked): .locked
        case .hud(let kind) where kind.style.keepsWings: .closed
        default: self
        }
    }
}
