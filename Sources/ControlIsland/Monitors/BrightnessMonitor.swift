import CoreGraphics
import Combine
import Foundation

@MainActor
final class BrightnessMonitor: ObservableObject {
    @Published private(set) var level: Float = 0
    @Published private(set) var available = false
    let changes = PassthroughSubject<Void, Never>()

    private let display = CGMainDisplayID()
    private var suppressNext = false
    private static weak var active: BrightnessMonitor?

    func start() {
        guard DisplayServices.isAvailable, DisplayServices.canChangeBrightness(display) else { return }
        available = true
        Self.active = self
        read(notify: false)
        DisplayServices.observeBrightness(of: display) { _, _, _, _, _ in
            Task { @MainActor in BrightnessMonitor.active?.read(notify: true) }
        }
    }

    func set(_ value: Float) {
        let clamped = min(max(value, 0), 1)
        suppressNext = true
        DisplayServices.setBrightness(clamped, of: display)
        level = clamped
    }

    private func read(notify: Bool) {
        guard let value = DisplayServices.brightness(of: display) else { return }
        level = value
        guard notify else { return }
        if suppressNext { suppressNext = false } else { changes.send() }
    }
}
