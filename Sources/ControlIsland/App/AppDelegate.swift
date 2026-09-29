import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let preferences = Preferences()
    private let mediaKeys = MediaKeyInterceptor()
    private lazy var state = IslandState(preferences: preferences)
    private lazy var settingsWindow = SettingsWindow(preferences: preferences, mediaKeys: mediaKeys)
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
    }

    func applicationWillTerminate(_ notification: Notification) {
        mediaKeys.deactivate()
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
