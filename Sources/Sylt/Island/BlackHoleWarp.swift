import AppKit

/// The black hole release effect's pointer choreography, in Cocoa screen coordinates.
@MainActor
enum BlackHoleWarp {
    private static let frameInterval: TimeInterval = 1 / 90
    private static let gapClosedPerStep: CGFloat = 0.45
    private static let suckSteps = 7
    private static let flingSpeed: CGFloat = 16
    private static let flingDrag: CGFloat = 0.8

    /// The visible pointer races to the island's middle in a few quick steps, closing the
    /// gap by a fixed share each time; `finish` gets where it ended, so it can be hidden there.
    static func suckIn(from start: CGPoint, to target: CGPoint, while holding: @escaping () -> Bool, then finish: @escaping (CGPoint) -> Void) {
        var position = start
        var step = 0
        Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { timer in
            MainActor.assumeIsolated {
                guard holding() else { return timer.invalidate() }
                step += 1
                position = CGPoint(x: position.x + (target.x - position.x) * gapClosedPerStep, y: position.y + (target.y - position.y) * gapClosedPerStep)
                CursorControl.warp(to: position)
                guard step >= suckSteps else { return }
                timer.invalidate()
                finish(position)
            }
        }
    }

    /// After the throw the pointer keeps going along the push and slows down, so it feels
    /// spat out rather than placed.
    static func fling(toward direction: CGVector) {
        guard direction.pushes else { return }
        let unit = direction.push.unit
        var speed = flingSpeed
        Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { timer in
            MainActor.assumeIsolated {
                speed *= flingDrag
                guard speed > 1 else { return timer.invalidate() }
                let location = NSEvent.mouseLocation
                CursorControl.warp(to: CGPoint(x: location.x + unit.dx * speed, y: location.y - unit.dy * speed))
            }
        }
    }
}
