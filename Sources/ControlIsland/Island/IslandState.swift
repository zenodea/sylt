import AppKit
import Combine

@MainActor
final class IslandState: ObservableObject {
    @Published var mode: IslandMode = .closed
    @Published var cursor: CGPoint = .zero
    @Published private(set) var layout = IslandLayout()

    let battery = BatteryMonitor()
    let volume = VolumeMonitor()
    let brightness = BrightnessMonitor()
    let herdr = HerdrMonitor()
    let nowPlaying = NowPlayingMonitor()

    private var hudTimer: Timer?
    private var collapseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    var notchHeight: CGFloat { layout.notchHeight }
    var notchWidth: CGFloat { layout.notchWidth }
    var canvasSize: CGSize { layout.canvasSize }

    var islandSize: CGSize {
        let expandedHeight = IslandLayout.expandedBaseHeight
            + (nowPlaying.track == nil ? 0 : IslandLayout.mediaCardHeight)
        return layout.size(for: mode, expandedHeight: expandedHeight)
    }

    func apply(_ geometry: NotchGeometry) {
        layout.notchWidth = geometry.notchWidth
        layout.notchHeight = geometry.notchHeight
    }

    func start() {
        battery.start()
        volume.start()
        brightness.start()
        herdr.start()
        nowPlaying.start()
        bindAlerts()
        bindLayout()
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

    func pressed() {
        guard mode != .expanded else { return }
        Haptics.press()
    }

    func released() {
        guard mode != .expanded else { return }
        hudTimer?.invalidate()
        mode = .expanded
        Haptics.expand()
    }

    private func bindAlerts() {
        volume.changes
            .sink { [weak self] in self?.showHUD(.volume) }
            .store(in: &cancellables)
        brightness.changes
            .sink { [weak self] in self?.showHUD(.brightness) }
            .store(in: &cancellables)
        battery.alerts
            .sink { [weak self] in self?.showHUD(.battery($0), duration: 2.5) }
            .store(in: &cancellables)
        herdr.finishedAgents
            .sink { [weak self] in self?.showHUD(.agentFinished($0), duration: 4) }
            .store(in: &cancellables)
        nowPlaying.trackChanges
            .sink { [weak self] in self?.showHUD(.nowPlaying, duration: 2.8) }
            .store(in: &cancellables)
    }

    private func bindLayout() {
        nowPlaying.$track
            .combineLatest(nowPlaying.$isPlaying, herdr.$available)
            .sink { [weak self] track, _, agents in
                guard let self else { return }
                layout.showsArtwork = track != nil
                layout.showsAudioBars = track != nil
                layout.showsAgents = agents
            }
            .store(in: &cancellables)
    }

    private func showHUD(_ kind: HUDKind, duration: TimeInterval = 1.6) {
        guard mode != .expanded else { return }
        mode = .hud(kind)
        hudTimer?.invalidate()
        hudTimer = .scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                if case .hud = self?.mode { self?.mode = .closed }
            }
        }
    }
}
