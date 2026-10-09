import AppKit
import Combine

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

    /// The front window says whether it is full screen. Without Accessibility, a window
    /// filling the screen's width and everything below the notch counts instead.
    private func refresh() {
        if let answer = frontWindowIsFullscreen() { isFullscreen = answer; return }
        guard let screen = NotchGeometry.preferredScreen() else { return }
        let top = NSScreen.screens[0].frame.maxY - screen.frame.maxY
        let inset = screen.safeAreaInsets.top
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
            as? [[String: Any]] ?? []
        isFullscreen = windows.contains { window in
            guard (window["kCGWindowLayer"] as? Int) == 0,
                  let frame = window["kCGWindowBounds"] as? [String: CGFloat]
            else { return false }
            let rect = CGRect(x: frame["X"] ?? 0, y: frame["Y"] ?? 0, width: frame["Width"] ?? 0, height: frame["Height"] ?? 0)
            return rect.minX == screen.frame.minX && rect.width == screen.frame.width
                && rect.minY <= top + inset && rect.height >= screen.frame.height - inset
        }
    }

    private func frontWindowIsFullscreen() -> Bool? {
        guard AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var window: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXFocusedWindowAttribute as CFString, &window) == .success, let window else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window as! AXUIElement, "AXFullScreen" as CFString, &value) == .success else { return nil }
        return value as? Bool
    }
}
