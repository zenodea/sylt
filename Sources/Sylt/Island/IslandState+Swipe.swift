import SwiftUI

/// Two-finger swipes over the island: the stretch while the fingers move, and what a finished one does.
extension IslandState {
    /// Scroll travel that pulls the island all the way; beyond it, winding further would only delay a reversal.
    static let swipeReach: CGFloat = 60

    func swipeMoved(_ vector: CGVector) {
        withAnimation(IslandAnimation.swipeFollow) {
            swipePull = CGVector(dx: Self.normalised(vector.dx), dy: Self.normalised(vector.dy))
        }
    }

    func swipeEnded() {
        withAnimation(IslandAnimation.swipeRebound) { swipePull = .zero }
    }

    func swiped(_ direction: SwipeDirection) {
        switch direction {
        case .down where mode != .expanded:
            expand()
            Haptics.expand()
        case .up where mode == .expanded:
            collapse()
        case .left where mode == .expanded && layout.expandedPages.count > 1:
            turnPage(1)
        case .right where mode == .expanded && layout.expandedPages.count > 1:
            turnPage(-1)
        case .left where nowPlaying.track != nil:
            changeTrack(nowPlaying.next, flashing: CGVector(dx: -1, dy: 0))
        case .right where nowPlaying.track != nil:
            changeTrack(nowPlaying.previous, flashing: CGVector(dx: 1, dy: 0))
        default:
            break
        }
    }

    private func changeTrack(_ change: () -> Void, flashing direction: CGVector) {
        change()
        flash(toward: direction)
        Haptics.press()
    }

    private static func normalised(_ travel: CGFloat) -> CGFloat {
        min(max(travel / swipeReach, -1), 1)
    }
}
