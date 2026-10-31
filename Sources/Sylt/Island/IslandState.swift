import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandState: ObservableObject {
    @Published var mode: IslandMode = .closed
    @Published private(set) var isHovering = false
    @Published var layout = IslandLayout()

    @Published var cursor: CGPoint = .zero
    @Published var cursorPull: CGVector = .zero
    @Published var pullStrength: CGFloat = 0
    @Published var exitPoint: CGPoint = .zero
    @Published var approachPoint: CGPoint = .zero
    @Published var approachStrength: CGFloat = 0
    var heldOrigin: CGPoint?

    @Published var burst: BurstEvent?
    @Published var liquid: LiquidEvent?
    @Published var sparks: SparkEvent?

    @Published var swipePull: CGVector = .zero
    var pageDirection = 1
    var listFrames: [CGRect] = []

    let preferences: Preferences
    let battery = BatteryMonitor()
    let volume = VolumeMonitor()
    let brightness = BrightnessMonitor()
    let nowPlaying = NowPlayingMonitor()
    let notifications = SystemNotificationMonitor()
    let bluetooth = BluetoothMonitor()
    let network = NetworkMonitor()
    let calendar = CalendarMonitor()
    let keyboard = KeyboardMonitor()
    let focus = FocusMonitor()
    let privacy = PrivacyMonitor()
    let thermal = ThermalMonitor()
    let plugins: PluginRegistry
    let lock = LockMonitor()
    let fullscreen = FullscreenMonitor()

    var hudTimer: Timer?
    var collapseTimer: Timer?
    var cancellables = Set<AnyCancellable>()
    private var hoveredItem: WingItem?

    private static let hudLinger: TimeInterval = 0.8
    private static let collapseDelay: TimeInterval = 0.3
    private static let swipeLeanWidth: CGFloat = 14
    private static let swipeLeanHeight: CGFloat = 10
    // Less than half the growth, so the edge the island leans away from still moves outward.
    private static let swipeLeanShift: CGFloat = 5

    init(preferences: Preferences, pluginStore: PluginStore? = nil) {
        self.preferences = preferences
        plugins = PluginRegistry(store: pluginStore ?? PluginStore())
    }

    func start() {
        lock.start()
        fullscreen.start()
        plugins.start()
        bindAlerts()
        bindLayout()
        bindPlugins()
        preferences.$enabledPlugins
            .combineLatest(preferences.$wingLayout)
            .sink { [weak self] enabled, wings in self?.applyPlugins(enabled.union(wings.monitorsNeeded)) }
            .store(in: &cancellables)
        preferences.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    var notchHeight: CGFloat { layout.notchHeight }
    var canvasSize: CGSize { layout.canvasSize }
    var hitFrame: CGRect { layout.hitFrame(for: mode, hovering: isHovering) }

    var islandFrame: IslandFrame {
        var frame = layout.frame(for: mode, hovering: isHovering)
        guard mode != .expanded, preferences.leansWithSwipes else { return frame }
        let strength = CGFloat(preferences.swipeLeanStrength)
        frame.size.width += abs(swipePull.dx) * Self.swipeLeanWidth * strength
        frame.size.height += max(0, swipePull.dy) * Self.swipeLeanHeight * strength
        frame.centerOffset += swipePull.dx * Self.swipeLeanShift * strength
        return frame
    }

    var absorbsCursor: Bool { preferences.absorbsPointer && isHovering && mode != .expanded && !lock.isLocked }

    var restingMode: IslandMode { lock.isLocked ? .locked : .closed }

    func hoverChanged(_ inside: Bool) {
        guard inside != isHovering else { return }
        withAnimation(IslandAnimation.peek) { isHovering = inside }
        collapseTimer?.invalidate()
        if inside {
            guard mode != .expanded else { return }
            hudTimer?.invalidate()
            Haptics.peek()
        } else if case .hud = mode {
            scheduleHUDDismissal(after: Self.hudLinger)
        } else if mode == .expanded {
            collapseTimer = .after(Self.collapseDelay) { [weak self] in self?.collapse() }
        } else {
            cursor = .zero
        }
    }

    func cursorMoved(to point: CGPoint) {
        let inside = hitFrame.contains(point)
        hoverChanged(inside)
        if !inside {
            hoveredItem = nil
        } else if mode != .expanded {
            hoveredItem = layout.item(at: point.x) ?? hoveredItem
        }
    }

    func pressed() {
        guard mode != .expanded else { return }
        Haptics.press()
    }

    func released() {
        guard mode != .expanded else { return }
        expand()
        Haptics.expand()
    }

    func dragEntered() {
        guard mode != .expanded, !lock.isLocked else { return }
        expand()
    }

    func dropped(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        plugins.dropped(urls)
        Haptics.expand()
    }

    func expand() {
        hudTimer?.invalidate()
        if let item = hoveredItem, let page = layout.page(for: item) { layout.expandedPage = page }
        transition(to: .expanded)
    }

    func collapse() {
        transition(to: .closed)
        Haptics.collapse()
    }

    func transition(to next: IslandMode) {
        withAnimation(IslandAnimation.transition(to: next)) { mode = next }
    }

    private func applyPlugins(_ enabled: Set<Plugin>) {
        for plugin in Plugin.allCases {
            enabled.contains(plugin) ? monitor(for: plugin).start() : monitor(for: plugin).stop()
        }
        if case .hud = mode { transition(to: restingMode) }
    }

    private func monitor(for plugin: Plugin) -> any Monitor {
        switch plugin {
        case .battery: battery
        case .volume: volume
        case .brightness: brightness
        case .nowPlaying: nowPlaying
        case .notifications: notifications
        case .bluetooth: bluetooth
        case .network: network
        case .calendar: calendar
        case .keyboard: keyboard
        case .focus: focus
        case .privacy: privacy
        case .thermals: thermal
        }
    }
}
