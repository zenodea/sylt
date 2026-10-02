import AppKit
import Combine
import SwiftUI

@MainActor
final class IslandState: ObservableObject {
    @Published var mode: IslandMode = .closed
    @Published var cursor: CGPoint = .zero
    @Published var swipePull: CGVector = .zero
    @Published private(set) var isHovering = false
    @Published private(set) var layout = IslandLayout()

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

    private var hudTimer: Timer?
    private var collapseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(preferences: Preferences, pluginStore: PluginStore? = nil) {
        self.preferences = preferences
        plugins = PluginRegistry(store: pluginStore ?? PluginStore())
    }

    var notchHeight: CGFloat { layout.notchHeight }
    var notchWidth: CGFloat { layout.notchWidth }
    var canvasSize: CGSize { layout.canvasSize }

    var islandFrame: IslandFrame { layout.frame(for: mode, hovering: isHovering) }
    var hitFrame: CGRect { layout.hitFrame(for: mode, hovering: isHovering) }

    /// Where the island settles when nothing is showing.
    private var restingMode: IslandMode { lock.isLocked ? .locked : .closed }

    func apply(_ geometry: NotchGeometry) {
        layout.notchWidth = geometry.notchWidth
        layout.notchHeight = geometry.notchHeight
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

    /// Files dragged onto the island land on the shelf; the island opens to show them.
    func dragEntered() {
        guard mode != .expanded, !lock.isLocked else { return }
        hudTimer?.invalidate()
        transition(to: .expanded)
    }

    func dropped(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        plugins.dropped(urls)
        Haptics.expand()
    }

    /// Plugin wings and sections feed the layout; a plugin's HUD goes through the usual gate.
    private func bindPlugins() {
        plugins.huds
            .sink { [weak self] plugin, hud in
                if let sound = hud.sound { Sounds.play(sound) }
                self?.showHUD(.external(ExternalHUD(pluginID: plugin.id, hud: hud)))
            }
            .store(in: &cancellables)
        plugins.$plugins
            .map { plugins in
                Publishers.MergeMany(plugins.map { plugin in
                    plugin.$left.combineLatest(plugin.$right, plugin.$section).map { _ in () }
                })
                .prepend(())
            }
            .switchToLatest()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.refreshPluginLayout() }
            .store(in: &cancellables)
    }

    private func refreshPluginLayout() {
        let running = plugins.plugins.filter(\.isRunning)
        layout.pluginLeft = running.map { PluginItem.width(of: $0.left, spacing: $0.leftSpacing) }
        layout.pluginRight = running.map { PluginItem.width(of: $0.right, spacing: $0.rightSpacing) }
        layout.pluginSections = running.compactMap { $0.section?.height }
    }

    func hoverChanged(_ inside: Bool) {
        guard inside != isHovering else { return }
        withAnimation(IslandAnimation.peek) { isHovering = inside }
        collapseTimer?.invalidate()
        if inside {
            switch mode {
            case .closed, .locked:
                Haptics.peek()
            case .hud:
                hudTimer?.invalidate()
                Haptics.peek()
            case .expanded:
                break
            }
        } else if case .hud = mode {
            scheduleHUDDismissal(after: 0.8)
        } else if mode == .expanded {
            collapseTimer = .after(0.3) { [weak self] in
                    self?.transition(to: .closed)
                    Haptics.collapse()
        }
        } else {
            cursor = .zero
        }
    }

    /// Drives hover from the cursor in canvas coordinates (top-left origin).
    func cursorMoved(to point: CGPoint) {
        guard hitFrame.contains(point) else { return hoverChanged(false) }
        hoverChanged(true)
        let frame = islandFrame
        let x = point.x - (layout.canvasSize.width - frame.size.width) / 2 - frame.centerOffset
        cursor = CGPoint(
            x: min(max(x / frame.size.width * 2 - 1, -1), 1),
            y: min(max(point.y / frame.size.height, 0), 1)
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
        show(volume.changes) { .volume }
        show(brightness.changes) { .brightness }
        show(battery.alerts) { .battery($0) }
        show(nowPlaying.trackChanges.merge(with: nowPlaying.playbackResumed)) { .nowPlaying }
        show(notifications.notifications) { .notification($0) }
        show(volume.muteChanges) { .mute($0) }
        show(bluetooth.events) { .bluetooth($0) }
        show(bluetooth.lowBattery) { .peripheralBattery($0) }
        show(network.changes) { .network($0) }
        show(calendar.reminders) { .calendar($0) }
        show(keyboard.capsLock) { .capsLock($0) }
        show(keyboard.inputSource) { .inputSource($0) }
        show(focus.changes) { .focus($0) }
        show(privacy.changes) { .privacy($0) }
        show(thermal.changes) { .thermal($0) }
        lock.$isLocked
            .dropFirst()
            .sink { [weak self] in $0 ? self?.locked() : self?.unlocked() }
            .store(in: &cancellables)
    }

    private func show<P: Publisher>(_ publisher: P, as kind: @escaping (P.Output) -> HUDKind) where P.Failure == Never {
        publisher
            .sink { [weak self] in self?.showHUD(kind($0)) }
            .store(in: &cancellables)
    }

    private func locked() {
        hudTimer?.invalidate()
        collapseTimer?.invalidate()
        transition(to: .locked)
    }

    private func unlocked() {
        if preferences.playsUnlockSound { Sounds.unlock() }
        if preferences.enabledHUDs.contains(.unlock) { showHUD(.unlocked) } else { transition(to: .closed) }
    }

    /// Normalised -1...1 pull in each axis; the island stretches that way and stays anchored to the notch.
    func swipeMoved(_ vector: CGVector) {
        withAnimation(IslandAnimation.swipeFollow) {
            swipePull = CGVector(dx: min(max(vector.dx / 60, -1), 1), dy: min(max(vector.dy / 60, -1), 1))
        }
    }

    func swipeEnded() {
        withAnimation(IslandAnimation.swipeRebound) { swipePull = .zero }
    }

    func swiped(_ direction: SwipeDirection) {
        switch direction {
        case .down where mode != .expanded:
            hudTimer?.invalidate()
            transition(to: .expanded)
            Haptics.expand()
        case .up where mode == .expanded:
            transition(to: .closed)
            Haptics.collapse()
        case .left where nowPlaying.track != nil:
            nowPlaying.next()
            Haptics.press()
        case .right where nowPlaying.track != nil:
            nowPlaying.previous()
            Haptics.press()
        default:
            break
        }
    }

    private func bindLayout() {
        fullscreen.$isFullscreen
            .sink { [weak self] in self?.layout.isFullscreen = $0 }
            .store(in: &cancellables)

        nowPlaying.$track
            .sink { [weak self] track in
                guard let self else { return }
                layout.showsArtwork = track != nil
                layout.showsAudioBars = track != nil
                layout.showsMediaCard = track != nil
            }
            .store(in: &cancellables)

        calendar.$next
            .combineLatest(calendar.$imminent)
            .sink { [weak self] next, imminent in
                self?.layout.showsNextEvent = next != nil
                self?.layout.showsCalendar = imminent
            }
            .store(in: &cancellables)

        privacy.$use
            .combineLatest(focus.$mode, bluetooth.$connected)
            .sink { [weak self] use, focus, connected in
                guard let self else { return }
                layout.privacyDots = (use.microphone ? 1 : 0) + (use.camera ? 1 : 0)
                layout.showsFocus = focus != nil
                layout.showsHeadphones = connected.contains { $0.isAudio && $0.battery != nil }
            }
            .store(in: &cancellables)
    }

    private func transition(to next: IslandMode) {
        withAnimation(IslandAnimation.transition(to: next)) { mode = next }
    }

    private func showHUD(_ kind: HUDKind) {
        guard mode != .expanded, preferences.enabledHUDs.contains(kind.category) else { return }
        transition(to: .hud(kind))
        scheduleHUDDismissal(after: kind.duration * preferences.hudDurationScale)
    }

    private func scheduleHUDDismissal(after duration: TimeInterval) {
        hudTimer?.invalidate()
        hudTimer = .after(duration) { [weak self] in
                guard let self, case .hud = self.mode, !self.isHovering else { return }
                self.transition(to: self.restingMode)
        }
    }

}
