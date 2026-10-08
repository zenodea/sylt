import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let mediaKeys = MediaKeyInterceptor()
    private lazy var state = IslandState(preferences: preferences)
    private lazy var settingsWindow = SettingsWindow(preferences: preferences, mediaKeys: mediaKeys, plugins: state.plugins)
    private var panel: NotchPanel?
    private var cancellables = Set<AnyCancellable>()
    private var activity: NSObjectProtocol?
    private var placementTimer: Timer?
    private var measureTimer: Timer?

    /// Displays settle late at login: the placement is checked often at first, then rarely.
    private static let earlyPlacementInterval: TimeInterval = 2
    private static let earlyPlacementChecks = 30
    private static let latePlacementInterval: TimeInterval = 15
    private static let measureInterval: TimeInterval = 2
    private static let mediaKeyStep: Float = 1 / 16
    private static let fineMediaKeyStep: Float = 1 / 64

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep], reason: "Island must react while the screen is locked")
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let panel = NotchPanel(screen: screen, state: state) { [weak self] in self?.settingsWindow.show() }
        panel.orderFrontRegardless()
        self.panel = panel
        state.start()
        bindMediaKeys()
        followDisplayChanges()
        keepPlacement()
        if !panel.isMeasured { measureNotchWhenMenuBarReturns() }
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeys.deactivate()
        state.plugins.stop()
    }

    private func followDisplayChanges() {
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let screen = NotchGeometry.preferredScreen() else { return }
                self?.panel?.relayout(on: screen)
            }
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.panel?.ensurePlacement() }
            }
        }
    }

    private func keepPlacement() {
        var checks = 0
        placementTimer = .every(Self.earlyPlacementInterval) { [weak self] in
            guard let self else { return }
            panel?.ensurePlacement()
            checks += 1
            guard checks == Self.earlyPlacementChecks else { return }
            placementTimer?.invalidate()
            placementTimer = .every(Self.latePlacementInterval) { [weak self] in self?.panel?.ensurePlacement() }
        }
    }

    /// Launched while the menu bar is away, the notch can't be measured yet: keep asking.
    private func measureNotchWhenMenuBarReturns() {
        measureTimer = .every(Self.measureInterval) { [weak self] in
            guard let self, let panel, let screen = NotchGeometry.preferredScreen() else { return }
            panel.relayout(on: screen)
            if panel.isMeasured { measureTimer?.invalidate() }
        }
    }

    private func bindMediaKeys() {
        mediaKeys.handler = { [state] key, fine in
            let step = fine ? Self.fineMediaKeyStep : Self.mediaKeyStep
            switch key {
            case .volumeUp: state.volume.step(step)
            case .volumeDown: state.volume.step(-step)
            case .mute: state.volume.toggleMute()
            case .brightnessUp: state.brightness.step(step)
            case .brightnessDown: state.brightness.step(-step)
            }
        }

        preferences.$enabledPlugins
            .combineLatest(preferences.$replacesSystemOverlays)
            .map { plugins, replaces in replaces && (plugins.contains(.volume) || plugins.contains(.brightness)) }
            .removeDuplicates()
            .sink { [mediaKeys] intercept in
                intercept ? mediaKeys.activate() : mediaKeys.deactivate()
            }
            .store(in: &cancellables)
    }
}
