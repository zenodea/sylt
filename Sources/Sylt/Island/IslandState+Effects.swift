import SwiftUI

/// The one-shot effects the pointer's arrival and release play on the island's surface.
extension IslandState {
    private static let burstDuration: TimeInterval = 1.1
    private static let sparkDuration: TimeInterval = 0.9
    private static let liquidDuration: TimeInterval = 0.7

    /// The surface reacts where the pointer just went in, the way the chosen release effect does.
    func pointerArrived(at point: CGPoint) {
        switch preferences.releaseEffect {
        case .ripple: splash(at: point)
        case .sparks, .blackHole: spark(at: point, direction: .zero, inward: true)
        default: break
        }
    }

    /// The chosen release effect at the rim in this direction: what the pointer leaving
    /// does, also played by a swipe that changes track.
    func flash(toward direction: CGVector) {
        guard direction.pushes, mode != .expanded else { return }
        let point = rimPoint(toward: direction, outside: 0)
        let unit = direction.push.unit
        play(BurstEvent(point: point, direction: unit), in: \.burst, for: Self.burstDuration)
        switch preferences.releaseEffect {
        case .ripple: splash(at: point)
        case .sparks, .blackHole: spark(at: point, direction: unit, inward: false)
        default: break
        }
    }

    private func splash(at point: CGPoint) {
        play(LiquidEvent(point: point), in: \.liquid, for: Self.liquidDuration)
    }

    private func spark(at point: CGPoint, direction: CGVector, inward: Bool) {
        play(SparkEvent(point: point, direction: direction, inward: inward), in: \.sparks, for: Self.sparkDuration)
    }

    /// Shows an event in its slot and clears it afterwards, unless a newer one has taken the slot.
    private func play<Event: Identifiable>(_ event: Event, in slot: ReferenceWritableKeyPath<IslandState, Event?>, for duration: TimeInterval) {
        self[keyPath: slot] = event
        Timer.after(duration) { [weak self] in
            guard let self, self[keyPath: slot]?.id == event.id else { return }
            self[keyPath: slot] = nil
        }
    }
}

/// The pointer just popped out here, pushed this way.
struct BurstEvent: Equatable, Identifiable {
    let point: CGPoint
    let direction: CGVector
    let id = UUID()
}

/// One disturbance of the island's liquid surface: where the pointer went in or came out.
struct LiquidEvent: Equatable, Identifiable {
    let point: CGPoint
    let start = Date()
    let id = UUID()
}

/// Sparks at a point: thrown out along a push, or drawn in when the pointer arrives.
struct SparkEvent: Equatable, Identifiable {
    let point: CGPoint
    let direction: CGVector
    let inward: Bool
    let start = Date()
    let id = UUID()
}
