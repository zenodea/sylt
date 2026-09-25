import AppKit
import Combine

@MainActor
final class IslandState: ObservableObject {
    @Published var mode: IslandMode = .closed
    @Published var geometry: NotchGeometry?

    let battery = BatteryMonitor()
    let volume = VolumeMonitor()
    let herdr = HerdrMonitor()

    let wingWidth: CGFloat = 70
    let expandedSize = CGSize(width: 520, height: 230)
    let hudHeight: CGFloat = 76

    private var hudTimer: Timer?
    private var collapseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    var notchWidth: CGFloat { geometry?.notchWidth ?? 180 }
    var notchHeight: CGFloat { geometry?.notchHeight ?? 32 }

    var canvasSize: CGSize {
        CGSize(width: expandedSize.width + 160, height: expandedSize.height + 80)
    }

    var islandSize: CGSize {
        switch mode {
        case .closed: CGSize(width: notchWidth + wingWidth * 2, height: notchHeight)
        case .hud: CGSize(width: notchWidth + wingWidth * 2 + 60, height: hudHeight)
        case .expanded: expandedSize
        }
    }

    func start() {
        battery.start()
        volume.start()
        herdr.start()

        volume.changes
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.showHUD(.volume) }
            .store(in: &cancellables)

        battery.chargerChanges
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.showHUD(.battery) }
            .store(in: &cancellables)
    }

    func hoverChanged(_ inside: Bool) {
        collapseTimer?.invalidate()
        if inside {
            hudTimer?.invalidate()
            mode = .expanded
        } else {
            collapseTimer = .scheduledTimer(withTimeInterval: 0.35, repeats: false) { [weak self] _ in
                Task { @MainActor in self?.mode = .closed }
            }
        }
    }

    private func showHUD(_ kind: HUDKind) {
        guard mode != .expanded else { return }
        mode = .hud(kind)
        hudTimer?.invalidate()
        hudTimer = .scheduledTimer(withTimeInterval: 1.6, repeats: false) { [weak self] _ in
            Task { @MainActor in
                if case .hud = self?.mode { self?.mode = .closed }
            }
        }
    }
}
