import CoreGraphics
import Combine
import Foundation

@MainActor
final class BrightnessMonitor: ObservableObject {
    @Published private(set) var level: Float = 0
    @Published private(set) var available = false
    let changes = PassthroughSubject<Void, Never>()

    private let display = CGMainDisplayID()
    private var observing = false
    private static weak var active: BrightnessMonitor?

    func start() {
        guard DisplayServices.isAvailable, DisplayServices.canChangeBrightness(display) else { return }
        available = true
        Self.active = self
        read(notify: false)
        guard !observing else { return }
        observing = DisplayServices.observeBrightness(of: display) { _, _, _, _, _ in
            Task { @MainActor in BrightnessMonitor.active?.read(notify: true) }
        }
    }

    func stop() {
        available = false
        Self.active = nil
    }

    func set(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        DisplayServices.setBrightness(clamped, of: display)
        level = clamped
    }

    func step(_ delta: Float) {
        set(level + delta)
    }

    private func read(notify: Bool) {
        guard let value = DisplayServices.brightness(of: display) else { return }
        level = value
        if notify { changes.send() }
    }
}
