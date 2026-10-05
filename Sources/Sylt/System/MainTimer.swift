import Foundation

extension Timer {
    /// A repeating timer whose body runs on the main actor.
    @MainActor
    static func every(_ interval: TimeInterval, _ body: @escaping @MainActor () -> Void) -> Timer {
        scheduledTimer(withTimeInterval: interval, repeats: true) { _ in Task { @MainActor in body() } }
    }

    /// A one-shot timer whose body runs on the main actor.
    @MainActor
    static func after(_ interval: TimeInterval, _ body: @escaping @MainActor () -> Void) -> Timer {
        scheduledTimer(withTimeInterval: interval, repeats: false) { _ in Task { @MainActor in body() } }
    }
}
