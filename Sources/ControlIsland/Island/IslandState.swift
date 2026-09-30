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
    let herdr = HerdrMonitor()
    let nowPlaying = NowPlayingMonitor()
    let notifications = SystemNotificationMonitor()
    let bluetooth = BluetoothMonitor()
    let network = NetworkMonitor()
    let calendar = CalendarMonitor()
    let timer = TimerMonitor()
    let keyboard = KeyboardMonitor()
    let focus = FocusMonitor()
    let privacy = PrivacyMonitor()
    let downloads = DownloadsMonitor()
    let weather = WeatherMonitor()
    let thermal = ThermalMonitor()
    let shelf = ShelfMonitor()
    let clipboard = ClipboardMonitor()
    let lock = LockMonitor()
    let fullscreen = FullscreenMonitor()

    private var hudTimer: Timer?
    private var collapseTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    init(preferences: Preferences) {
        self.preferences = preferences
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
        if case .hud = mode { transition(to: restingMode) }
    }

    private func monitor(for plugin: Plugin) -> any Monitor {
        switch plugin {
        case .battery: battery
        case .volume: volume
        case .brightness: brightness
        case .nowPlaying: nowPlaying
        case .herdr: herdr
        case .notifications: notifications
        case .bluetooth: bluetooth
        case .network: network
        case .calendar: calendar
        case .timer: timer
        case .keyboard: keyboard
        case .focus: focus
        case .privacy: privacy
        case .downloads: downloads
        case .weather: weather
        case .thermals: thermal
        case .shelf: shelf
        case .clipboard: clipboard
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
        shelf.add(urls)
        Haptics.expand()
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
            collapseTimer = .scheduledTimer(withTimeInterval: 0.3, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.transition(to: .closed)
                    Haptics.collapse()
                }
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
        volume.changes
            .sink { [weak self] in self?.showHUD(.volume) }
            .store(in: &cancellables)
        volume.muteChanges
            .sink { [weak self] in self?.showHUD(.mute($0)) }
            .store(in: &cancellables)
        bluetooth.events
            .sink { [weak self] in self?.showHUD(.bluetooth($0)) }
            .store(in: &cancellables)
        network.changes
            .sink { [weak self] in self?.showHUD(.network($0)) }
            .store(in: &cancellables)
        bluetooth.lowBattery
            .sink { [weak self] in self?.showHUD(.peripheralBattery($0)) }
            .store(in: &cancellables)
        calendar.reminders
            .sink { [weak self] in self?.showHUD(.calendar($0)) }
            .store(in: &cancellables)
        timer.finished
            .sink { [weak self] in self?.showHUD(.timerDone($0)) }
            .store(in: &cancellables)
        keyboard.capsLock
            .sink { [weak self] in self?.showHUD(.capsLock($0)) }
            .store(in: &cancellables)
        keyboard.inputSource
            .sink { [weak self] in self?.showHUD(.inputSource($0)) }
            .store(in: &cancellables)
        focus.changes
            .sink { [weak self] in self?.showHUD(.focus($0)) }
            .store(in: &cancellables)
        privacy.changes
            .sink { [weak self] in self?.showHUD(.privacy($0)) }
            .store(in: &cancellables)
        downloads.events
            .sink { [weak self] in self?.showHUD(.download($0)) }
            .store(in: &cancellables)
        thermal.changes
            .sink { [weak self] in self?.showHUD(.thermal($0)) }
            .store(in: &cancellables)
        brightness.changes
            .sink { [weak self] in self?.showHUD(.brightness) }
            .store(in: &cancellables)
        battery.alerts
            .sink { [weak self] in self?.showHUD(.battery($0)) }
            .store(in: &cancellables)
        herdr.finishedAgents
            .sink { [weak self] in self?.showHUD(.agentFinished($0)) }
            .store(in: &cancellables)
        nowPlaying.trackChanges
            .merge(with: nowPlaying.playbackResumed)
            .sink { [weak self] in self?.showHUD(.nowPlaying) }
            .store(in: &cancellables)
        notifications.notifications
            .sink { [weak self] in self?.showHUD(.notification($0)) }
            .store(in: &cancellables)
        lock.$isLocked
            .dropFirst()
            .sink { [weak self] in $0 ? self?.locked() : self?.unlocked() }
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

        calendar.$next
            .combineLatest(calendar.$imminent, timer.$end, preferences.$enabledPlugins)
            .sink { [weak self] next, imminent, end, plugins in
                guard let self else { return }
                layout.showsNextEvent = next != nil
                layout.showsCalendar = imminent
                layout.showsTimer = end != nil
                layout.showsTimerControls = plugins.contains(.timer)
            }
            .store(in: &cancellables)

        privacy.$use
            .combineLatest(focus.$mode, bluetooth.$connected, weather.$report)
            .sink { [weak self] use, focus, connected, report in
                guard let self else { return }
                layout.privacyDots = (use.microphone ? 1 : 0) + (use.camera ? 1 : 0)
                layout.showsFocus = focus != nil
                layout.showsHeadphones = connected.contains { $0.isAudio && $0.battery != nil }
                layout.showsWeather = report != nil
            }
            .store(in: &cancellables)

        shelf.$files
            .combineLatest(clipboard.$items)
            .sink { [weak self] files, items in
                self?.layout.shelfFiles = files.count
                self?.layout.clipboardRows = items.count
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
        hudTimer = .scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self, case .hud = self.mode, !self.isHovering else { return }
                self.transition(to: self.restingMode)
            }
        }
    }

}
