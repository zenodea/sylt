import Combine
import CoreWLAN
import Foundation
import Network

@MainActor
final class NetworkMonitor: ObservableObject {
    enum Link: Hashable, CaseIterable {
        case wifi, ethernet, other, offline
    }

    let changes = PassthroughSubject<Link, Never>()
    @Published private(set) var link: Link = .offline
    @Published private(set) var signal: Double = 0

    private var monitor: NWPathMonitor?
    private var current: Link?
    private var settle: Timer?
    private var signalTimer: Timer?

    func start() {
        guard monitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let link = Self.link(for: path)
            Task { @MainActor in self?.observed(link) }
        }
        monitor.start(queue: .global(qos: .utility))
        self.monitor = monitor
        readSignal()
        signalTimer = .every(5) { [weak self] in self?.readSignal() }
    }

    func stop() {
        monitor?.cancel()
        monitor = nil
        settle?.invalidate()
        settle = nil
        signalTimer?.invalidate()
        signalTimer = nil
        current = nil
    }

    private func readSignal() {
        guard link == .wifi, let rssi = CWWiFiClient.shared().interface()?.rssiValue(), rssi != 0 else { signal = 0; return }
        signal = switch rssi {
        case (-55)...: 1
        case (-67)...: 0.66
        case (-78)...: 0.33
        default: 0.1
        }
    }

    private func observed(_ link: Link) {
        guard current != nil else { adopt(link); return }
        settle?.invalidate()
        settle = .after(1.2) { [weak self] in
            guard let self, link != current else { return }
            adopt(link)
            changes.send(link)
        }
    }

    private func adopt(_ link: Link) {
        current = link
        self.link = link
        readSignal()
    }

    nonisolated private static func link(for path: NWPath) -> Link {
        guard path.status == .satisfied else { return .offline }
        if path.usesInterfaceType(.wiredEthernet) { return .ethernet }
        if path.usesInterfaceType(.wifi) { return .wifi }
        return .other
    }
}

extension NetworkMonitor.Link {
    var title: String {
        switch self {
        case .wifi: "Wi-Fi"
        case .ethernet: "Ethernet"
        case .other: "Online"
        case .offline: "Offline"
        }
    }

    var symbol: String {
        switch self {
        case .wifi: "wifi"
        case .ethernet: "cable.connector.horizontal"
        case .other: "network"
        case .offline: "wifi.slash"
        }
    }
}
