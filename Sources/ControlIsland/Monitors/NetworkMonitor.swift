import Combine
import Foundation
import Network

/// Which link carries the default route, reported when it changes.
@MainActor
final class NetworkMonitor: ObservableObject {
    enum Link: Hashable, CaseIterable {
        case wifi, ethernet, other, offline
    }

    let changes = PassthroughSubject<Link, Never>()

    private var monitor: NWPathMonitor?
    private var current: Link?
    private var settle: Timer?

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let link = Self.link(for: path)
            Task { @MainActor in self?.observed(link) }
        }
        monitor.start(queue: .global(qos: .utility))
        self.monitor = monitor
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
        settle?.invalidate()
        current = nil
    }

    /// Paths flap while a connection comes up; report once it has held for a moment.
    private func observed(_ link: Link) {
        guard current != nil else { current = link; return }
        settle?.invalidate()
        settle = .scheduledTimer(withTimeInterval: 1.2, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, link != self.current else { return }
                self.current = link
                self.changes.send(link)
            }
        }
    }

    nonisolated private static func link(for path: NWPath) -> Link {
        guard path.status == .satisfied else { return .offline }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        if path.usesInterfaceType(.wifi) { return .wifi }
        return .other
    }
}
