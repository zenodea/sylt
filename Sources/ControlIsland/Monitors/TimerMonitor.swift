import Combine
import Foundation

/// A single countdown, started from the island.
@MainActor
final class TimerMonitor: ObservableObject {
    @Published private(set) var end: Date?
    @Published private(set) var duration: TimeInterval = 0
    let finished = PassthroughSubject<TimeInterval, Never>()

    static let presets: [TimeInterval] = [5 * 60, 15 * 60, 25 * 60, 60 * 60]

    private var ticker: Timer?

    var isRunning: Bool { end != nil }

    func start() {}

    func stop() { cancel() }

    func begin(_ seconds: TimeInterval) {
        duration = seconds
        end = Date().addingTimeInterval(seconds)
        ticker?.invalidate()
        ticker = .scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.tick() }
        }
    }

    func cancel() {
        ticker?.invalidate()
        ticker = nil
        end = nil
    }

    func remaining(at now: Date = .now) -> TimeInterval {
        max(0, end?.timeIntervalSince(now) ?? 0)
    }

    private func tick() {
        guard let end, Date() >= end else { return }
        cancel()
        Sounds.timer()
        finished.send(duration)
    }
}
