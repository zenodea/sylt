import AppKit
import Combine

@MainActor
final class IslandState: ObservableObject {
    @Published var mode: IslandMode = .closed
    @Published var geometry: NotchGeometry?
    @Published var cursor: CGPoint = .zero

    let battery = BatteryMonitor()
    let volume = VolumeMonitor()
    let brightness = BrightnessMonitor()
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
        case .peek: CGSize(width: notchWidth + wingWidth * 2 + 18, height: notchHeight + 7)
        case .hud: CGSize(width: notchWidth + wingWidth * 2 + 60, height: hudHeight)
        case .expanded: expandedSize
        }
    }

    func start() {
        battery.start()
        volume.start()
        brightness.start()
        herdr.start()

        volume.changes
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.showHUD(.volume) }
            .store(in: &cancellables)

        brightness.changes
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.showHUD(.brightness) }
            .store(in: &cancellables)

        battery.chargerChanges
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.showHUD(.battery) }
            .store(in: &cancellables)
    }

    func hoverChanged(_ inside: Bool) {
        collapseTimer?.invalidate()
        if inside {
            if mode == .closed {
                mode = .peek
                Haptics.peek()
            }
        } else if mode == .expanded {
            collapseTimer = .scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.mode = .closed
                    Haptics.collapse()
                }
            }
        } else {
            cursor = .zero
            if mode == .peek { mode = .closed }
        }
    }

    func cursorMoved(to location: CGPoint, in size: CGSize) {
        cursor = CGPoint(
            x: min(max(location.x / size.width * 2 - 1, -1), 1),
            y: min(max(location.y / size.height, 0), 1)
        )
    }

    func tapped() {
        guard mode != .expanded else { return }
        hudTimer?.invalidate()
        mode = .expanded
        Haptics.expand()
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
