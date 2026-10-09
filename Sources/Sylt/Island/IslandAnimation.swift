import SwiftUI

enum IslandAnimation {
    static let peek = Animation.spring(response: 0.28, dampingFraction: 0.7)
    static let expand = Animation.spring(response: 0.48, dampingFraction: 0.72)
    /// Critically damped: any overshoot on the way down would show the notch.
    static let collapse = Animation.spring(response: 0.36, dampingFraction: 1)
    static let hud = Animation.spring(response: 0.4, dampingFraction: 0.68)
    static let cursor = Animation.interactiveSpring(response: 0.22, dampingFraction: 0.78)
    static let press = Animation.spring(response: 0.2, dampingFraction: 0.6)
    static let value = Animation.spring(response: 0.3, dampingFraction: 0.85)
    static let unlock = Animation.spring(response: 0.45, dampingFraction: 0.5)

    static func transition(to mode: IslandMode) -> Animation {
        switch mode {
        case .expanded: expand
        case .hud, .locked: hud
        case .closed: collapse
        }
    }

    /// Content waits for the shape to open, then blurs in; it leaves quickly.
    static var content: some Transition {
        AsymmetricTransition(
            insertion: BlurReplaceTransition(configuration: .downUp).animation(.easeOut(duration: 0.28).delay(0.1)),
            removal: BlurReplaceTransition(configuration: .downUp).animation(.easeIn(duration: 0.12))
        )
    }

    static let swipeFollow = Animation.interactiveSpring(response: 0.2, dampingFraction: 0.8)
    /// Damped enough that the island settling back never dips under its resting size.
    static let swipeRebound = Animation.spring(response: 0.34, dampingFraction: 0.86)

    static func stagger(_ index: Int) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.8).delay(0.12 + Double(index) * 0.06)
    }
}
