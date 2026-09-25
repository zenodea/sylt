import SwiftUI

enum IslandAnimation {
    static let peek = Animation.spring(response: 0.26, dampingFraction: 0.72)
    static let cursor = Animation.interactiveSpring(response: 0.22, dampingFraction: 0.78)
    static let expand = Animation.spring(response: 0.45, dampingFraction: 0.68)
    static let collapse = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let hud = Animation.spring(response: 0.42, dampingFraction: 0.66)

    static func transition(to mode: IslandMode) -> Animation {
        switch mode {
        case .peek: peek
        case .expanded: expand
        case .hud: hud
        case .closed: collapse
        }
    }
}
