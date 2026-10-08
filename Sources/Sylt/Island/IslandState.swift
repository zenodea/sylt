import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandState: ObservableObject {
    @Published var mode: IslandMode = .closed
    @Published private(set) var isHovering = false
    @Published var layout = IslandLayout()

    /// The push on the held pointer: the content's lean, the island's lean (-1...1 per
    /// axis), how close the pointer is to popping out (0...1) and where on the rim it would.
    @Published var cursor: CGPoint = .zero
    @Published var cursorPull: CGVector = .zero
    @Published var pullStrength: CGFloat = 0
    @Published var exitPoint: CGPoint = .zero
    /// Where the pointer went in, in canvas coordinates; pushes are measured from here.
    var heldOrigin: CGPoint?

    @Published var burst: BurstEvent?
    @Published var liquid: LiquidEvent?
    @Published var sparks: SparkEvent?

    /// The swipe under way, -1...1 per axis, and which way the last page turn went.
    @Published var swipePull: CGVector = .zero
    var pageDirection = 1
    /// Where scrolling lists are on the canvas, so a scroll over one stays the list's.
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

    /// How long a HUD the pointer just left stays, and how long the open panel waits before closing.
    private static let hudLinger: TimeInterval = 0.8
    private static let collapseDelay: TimeInterval = 0.3
    /// How far the island's edge reaches into a swipe, per unit of pull.
    private static let swipeLeanWidth: CGFloat = 14
    private static let swipeLeanHeight: CGFloat = 10
    private static let swipeLeanShift: CGFloat = 7

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
            .sink { [weak self] in self?.applyPlugins($0) }
            .store(in: &cancellables)
    }

    var notchHeight: CGFloat { layout.notchHeight }
    var notchWidth: CGFloat { layout.notchWidth }
    var canvasSize: CGSize { layout.canvasSize }
    var hitFrame: CGRect { layout.hitFrame(for: mode, hovering: isHovering) }

    /// The island's frame, leaning into a swipe: its edge reaches a little that way while
    /// the content inside stays where it is, so it moves like a body, not like jelly.
    var islandFrame: IslandFrame {
        var frame = layout.frame(for: mode, hovering: isHovering)
        guard mode != .expanded, preferences.leansWithSwipes else { return frame }
        let strength = CGFloat(preferences.swipeLeanStrength)
        frame.size.width += abs(swipePull.dx) * Self.swipeLeanWidth * strength
        frame.size.height += max(0, swipePull.dy) * Self.swipeLeanHeight * strength
        frame.centerOffset += swipePull.dx * Self.swipeLeanShift * strength
        return frame
    }

    /// The island takes the cursor in everywhere except the expanded panel, which has controls to click.
    var absorbsCursor: Bool { preferences.absorbsPointer && isHovering && mode != .expanded && !lock.isLocked }

    /// Where the island settles when nothing is showing.
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

    /// Drives hover from the cursor in canvas coordinates (top-left origin).
    func cursorMoved(to point: CGPoint) {
        hoverChanged(hitFrame.contains(point))
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

    /// Files dragged onto the island land on the shelf; the island opens to show them.
    func dragEntered() {
        guard mode != .expanded, !lock.isLocked else { return }
        expand()
    }

    func dropped(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        plugins.dropped(urls)
        Haptics.expand()
    }

    /// Opens the panel; whatever HUD was showing gives way.
    func expand() {
        hudTimer?.invalidate()
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
