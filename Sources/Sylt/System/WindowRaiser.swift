import AppKit

/// Brings one of an app's windows forward through Accessibility.
enum WindowRaiser {
    static func raise(in application: NSRunningApplication, titleContaining needle: String?) {
        let app = AXUIElementCreateApplication(application.processIdentifier)
        var value: AnyObject?
        guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement], !windows.isEmpty
        else { return }
        let match = needle.flatMap { needle in windows.first { title(of: $0).localizedCaseInsensitiveContains(needle) } }
        AXUIElementPerformAction(match ?? windows[0], kAXRaiseAction as CFString)
    }

    private static func title(of window: AXUIElement) -> String {
        var value: AnyObject?
        AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &value)
        return value as? String ?? ""
    }
}
