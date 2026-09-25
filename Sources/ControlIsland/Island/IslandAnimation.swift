import SwiftUI

enum IslandAnimation {
    static let expand = Animation.spring(response: 0.45, dampingFraction: 0.68)
    static let collapse = Animation.spring(response: 0.38, dampingFraction: 0.82)
    static let hud = Animation.spring(response: 0.42, dampingFraction: 0.66)

    static func transition(to mode: IslandMode) -> Animation {
        switch mode {
        case .expanded: expand
        case .hud: hud
        case .closed: collapse
        }
    }
}
