import Combine
import CoreGraphics
import Foundation
import QuartzCore

@MainActor
final class BrightnessMonitor: ObservableObject {
    @Published private(set) var level: Float = 0
    let changes = PassthroughSubject<Void, Never>()

    private let display = CGMainDisplayID()
    private var observing = false
    private var ownChangeAt: CFTimeInterval = 0
    // Smaller than the finest key step (1/64), larger than auto-brightness's creep.
    private static let manualStep: Float = 1 / 64 * 0.8
    private static weak var active: BrightnessMonitor?

    func start() {
        guard DisplayServices.isAvailable, DisplayServices.canChangeBrightness(display) else { return }
        Self.active = self
        read()
        guard !observing else { return }
        observing = DisplayServices.observeBrightness(of: display) { _, _, _, _, _ in
            Task { @MainActor in BrightnessMonitor.active?.read() }
        }
    }

    func stop() {
        Self.active = nil
    }

    func set(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        DisplayServices.setBrightness(clamped, of: display)
        level = clamped
        ownChangeAt = CACurrentMediaTime()
        changes.send()
    }

    func step(_ delta: Float) {
        set(level + delta)
    }

    private func read() {
        guard let value = DisplayServices.brightness(of: display) else { return }
        let previous = level
        level = value
        let own = CACurrentMediaTime() - ownChangeAt < 0.5
        DebugLog.write("brightness: \(value) from \(previous) own=\(own)")
        if !own, observing, abs(value - previous) >= Self.manualStep { changes.send() }
    }
}
