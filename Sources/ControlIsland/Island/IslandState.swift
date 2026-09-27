import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandState: ObservableObject {
    @Published var mode: IslandMode = .closed
    @Published var cursor: CGPoint = .zero
    private var isHovering = false
    @Published private(set) var layout = IslandLayout()

    let preferences: Preferences
    let battery = BatteryMonitor()
    let volume = VolumeMonitor()
    let brightness = BrightnessMonitor()
    let herdr = HerdrMonitor()
    let nowPlaying = NowPlayingMonitor()

    private var hudTimer: Timer?
    private var collapseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(preferences: Preferences) {
        self.preferences = preferences
    }

    var notchHeight: CGFloat { layout.notchHeight }
    var notchWidth: CGFloat { layout.notchWidth }
    var canvasSize: CGSize { layout.canvasSize }

    var islandSize: CGSize { layout.size(for: mode) }

    func apply(_ geometry: NotchGeometry) {
        layout.notchWidth = geometry.notchWidth
        layout.notchHeight = geometry.notchHeight
    }

    func start() {
        bindAlerts()
        bindLayout()
        preferences.$enabledPlugins
            .sink { [weak self] in self?.applyPlugins($0) }
            .store(in: &cancellables)
    }

    private func applyPlugins(_ enabled: Set<Plugin>) {
        for plugin in Plugin.allCases {
            enabled.contains(plugin) ? monitor(for: plugin).start() : monitor(for: plugin).stop()
        }
        if case .hud = mode { transition(to: .closed) }
    }

    private func monitor(for plugin: Plugin) -> any Monitor {
        switch plugin {
        case .battery: battery
        case .volume: volume
        case .brightness: brightness
        case .nowPlaying: nowPlaying
        case .herdr: herdr
        }
    }

    func hoverChanged(_ inside: Bool) {
        guard inside != isHovering else { return }
        isHovering = inside
        collapseTimer?.invalidate()
        if inside {
            if mode == .closed {
                transition(to: .peek)
                Haptics.peek()
            }
        } else if mode == .expanded {
            collapseTimer = .scheduledTimer(withTimeInterval: 0.2, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.transition(to: .closed)
                    Haptics.collapse()
                }
            }
        } else {
            cursor = .zero
            if mode == .peek { transition(to: .closed) }
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
        transition(to: .expanded)
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
            .combineLatest(herdr.$available, herdr.$agents)
            .sink { [weak self] track, agentsAvailable, agents in
                guard let self else { return }
                layout.showsArtwork = track != nil
                layout.showsAudioBars = track != nil
                layout.showsMediaCard = track != nil
                layout.showsAgents = agentsAvailable
                layout.agentRows = agentsAvailable ? agents.count : 0
            }
            .store(in: &cancellables)
    }

    private func transition(to next: IslandMode) {
        withAnimation(IslandAnimation.transition(to: next)) { mode = next }
    }

    private func showHUD(_ kind: HUDKind, duration: TimeInterval = 1.6) {
        guard mode != .expanded else { return }
        transition(to: .hud(kind))
        hudTimer?.invalidate()
        hudTimer = .scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                if case .hud = self?.mode { self?.transition(to: .closed) }
            }
        }
    }
}
