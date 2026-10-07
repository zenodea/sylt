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

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(
            options: [.userInitiatedAllowingIdleSystemSleep], reason: "Island must react while the screen is locked")
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let panel = NotchPanel(screen: screen, state: state) { [weak self] in self?.settingsWindow.show() }
        panel.orderFrontRegardless()
        self.panel = panel
        state.start()
        bindMediaKeys()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil, queue: .main
        ) { [weak self] _ in
            guard let self, let screen = NotchGeometry.preferredScreen() else { return }
            self.panel?.relayout(on: screen)
        }
        for name in [NSWorkspace.didWakeNotification, NSWorkspace.activeSpaceDidChangeNotification, NSWorkspace.screensDidWakeNotification] {
            NSWorkspace.shared.notificationCenter.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.panel?.ensurePlacement() }
            }
        }
        // Displays settle late at login; keep checking the placement, often at first, then rarely.
        var checks = 0
        Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, let panel = self.panel else { return timer.invalidate() }
                panel.ensurePlacement()
                checks += 1
                if checks == 30 {
                    timer.invalidate()
                    Timer.scheduledTimer(withTimeInterval: 15, repeats: true) { _ in MainActor.assumeIsolated { panel.ensurePlacement() } }
                }
            }
        }
        // Launched while the menu bar is away, the notch can't be measured yet: keep asking.
        if !panel.isMeasured {
            Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] timer in
                MainActor.assumeIsolated {
                    guard let self, let panel = self.panel, let screen = NotchGeometry.preferredScreen() else { return timer.invalidate() }
                    panel.relayout(on: screen)
                    if panel.isMeasured { timer.invalidate() }
                }
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeys.deactivate()
        state.plugins.stop()
    }

    private func bindMediaKeys() {
        mediaKeys.handler = { [state] key, fine in
            let step: Float = fine ? 1 / 64 : 1 / 16
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
