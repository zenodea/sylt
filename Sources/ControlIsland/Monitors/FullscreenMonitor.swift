import AppKit
import Combine

/// Whether the active space is showing a full-screen app.
@MainActor
final class FullscreenMonitor: ObservableObject {
    @Published private(set) var isFullscreen = false

    private var observers: [NSObjectProtocol] = []

    func start() {
        guard observers.isEmpty else { return }
        let center = NSWorkspace.shared.notificationCenter
        let names: [Notification.Name] = [
            NSWorkspace.activeSpaceDidChangeNotification,
            NSWorkspace.didActivateApplicationNotification,
        ]
        observers = names.map { name in
            center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor in self?.refresh() }
            }
        }
        refresh()
    }

    func stop() {
        observers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        observers = []
    }

    private func refresh() {
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let bounds = CGRect(
            x: screen.frame.minX,
            y: NSScreen.screens[0].frame.maxY - screen.frame.maxY,
            width: screen.frame.width,
            height: screen.frame.height
        )
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        isFullscreen = windows.contains { window in
            guard (window["kCGWindowLayer"] as? Int) == 0,
                  let frame = window["kCGWindowBounds"] as? [String: CGFloat]
            else { return false }
            let rect = CGRect(x: frame["X"] ?? 0, y: frame["Y"] ?? 0, width: frame["Width"] ?? 0, height: frame["Height"] ?? 0)
            return rect == bounds
        }
    }
}
