import CoreGraphics
import QuartzCore
import Combine
import Foundation

@MainActor
final class BrightnessMonitor: ObservableObject {
    @Published var level: Float = 0
    @Published private(set) var available = false
    /// Only changes made through the island. Auto-brightness and other
    /// sources update the level without an overlay.
    let changes = PassthroughSubject<Void, Never>()

    private let display = CGMainDisplayID()
    private var observing = false
    private var ownChangeAt: CFTimeInterval = 0
    /// A key press moves brightness by a sixteenth, or a sixty-fourth with the fine
    /// modifiers. Auto-brightness creeps in far smaller steps than that.
    private static let manualStep: Float = 1 / 64 * 0.8
    private static weak var active: BrightnessMonitor?

    func start() {
        guard DisplayServices.isAvailable, DisplayServices.canChangeBrightness(display) else { return }
        available = true
        Self.active = self
        read()
        guard !observing else { return }
        observing = DisplayServices.observeBrightness(of: display) { _, _, _, _, _ in
            Task { @MainActor in BrightnessMonitor.active?.read() }
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
        ownChangeAt = CACurrentMediaTime()
        if ProcessInfo.processInfo.environment["ISLAND_DEBUG"] != nil {
            FileHandle.standardError.write(Data("brightness: set \(clamped)\n".utf8))
        }
        changes.send()
    }

    func step(_ delta: Float) {
        set(level + delta)
    }

    /// A change made elsewhere. A jump the size of a key step is someone adjusting the
    /// brightness, through a key the island didn't catch or a slider, and gets the overlay.
    private func read() {
        guard let value = DisplayServices.brightness(of: display) else { return }
        let previous = level
        level = value
        let own = CACurrentMediaTime() - ownChangeAt < 0.5
        if ProcessInfo.processInfo.environment["ISLAND_DEBUG"] != nil {
            FileHandle.standardError.write(Data("brightness: notified \(value) from \(previous) own=\(own)\n".utf8))
        }
        if !own, observing, abs(value - previous) >= Self.manualStep { changes.send() }
    }
}
