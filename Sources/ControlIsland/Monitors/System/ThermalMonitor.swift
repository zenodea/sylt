import Combine
import Foundation

/// The system thermal state; reported when the Mac starts to throttle and
/// again once it has cooled down.
@MainActor
final class ThermalMonitor: ObservableObject {
    @Published private(set) var state = ProcessInfo.processInfo.thermalState
    let changes = PassthroughSubject<ProcessInfo.ThermalState, Never>()

    private var observer: NSObjectProtocol?

    var isHot: Bool { state == .serious || state == .critical }

    func start() {
        guard observer == nil else { return }
        state = ProcessInfo.processInfo.thermalState
        observer = NotificationCenter.default.addObserver(
            forName: ProcessInfo.thermalStateDidChangeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                let next = ProcessInfo.processInfo.thermalState
                guard next != self.state else { return }
                let wasHot = self.isHot
                self.state = next
                if self.isHot != wasHot { self.changes.send(next) }
            }
        }
    }

    func stop() {
        observer.map(NotificationCenter.default.removeObserver)
        observer = nil
    }
}

extension ProcessInfo.ThermalState {
    var title: String {
        switch self {
        case .nominal: "Cool"
        case .fair: "Warm"
        case .serious: "Hot"
        case .critical: "Throttling"
        @unknown default: "Unknown"
        }
    }
}
