import AppKit
import Combine

@MainActor
final class LockMonitor: ObservableObject {
    let unlocked = PassthroughSubject<Void, Never>()

    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        let center = DistributedNotificationCenter.default()
        observers = [
            center.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.unlocked.send() }
            },
        ]
    }

    func stop() {
        observers.forEach(DistributedNotificationCenter.default().removeObserver)
        observers = []
    }
}
