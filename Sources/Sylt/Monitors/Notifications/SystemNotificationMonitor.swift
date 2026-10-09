import AppKit
import ApplicationServices
import Combine

/// Mirrors Notification Center banners by watching its windows through the
/// Accessibility API. Experimental: depends on the banner's element layout.
@MainActor
final class SystemNotificationMonitor: ObservableObject {
    let notifications = PassthroughSubject<SystemNotification, Never>()

    private var observer: AXObserver?
    private var application: AXUIElement?
    private var seen: Set<String> = []

    func start() {
        guard observer == nil, AXIsProcessTrusted(),
              let center = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.notificationcenterui").first
        else { return }
        let pid = center.processIdentifier
        var created: AXObserver?
        guard AXObserverCreate(pid, { _, element, _, info in
            guard let info else { return }
            let monitor = Unmanaged<SystemNotificationMonitor>.fromOpaque(info).takeUnretainedValue()
            MainActor.assumeIsolated { monitor.inspect(element) }
        }, &created) == .success, let created else { return }

        let application = AXUIElementCreateApplication(pid)
        let context = Unmanaged.passUnretained(self).toOpaque()
        AXObserverAddNotification(created, application, kAXWindowCreatedNotification as CFString, context)
        AXObserverAddNotification(created, application, kAXLayoutChangedNotification as CFString, context)
        CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(created), .defaultMode)
        observer = created
        self.application = application
    }

    func stop() {
        if let observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
        }
        observer = nil
        application = nil
        seen = []
    }

    private func inspect(_ element: AXUIElement) {
        let texts = Self.staticTexts(in: element)
        guard texts.count >= 2 else { return }
        let key = texts.joined(separator: "\u{1F}")
        guard !seen.contains(key) else { return }
        seen.insert(key)
        if seen.count > 50 { seen = [key] }

        let appName = texts.count >= 3 ? texts[0] : ""
        let title = texts.count >= 3 ? texts[1] : texts[0]
        let body = texts.count >= 3 ? texts[2...].joined(separator: " ") : texts[1]
        let bundle = AppIcons.bundle(named: appName)
        notifications.send(SystemNotification(appName: appName, title: title, body: body, bundleIdentifier: bundle))
    }

    private static func staticTexts(in element: AXUIElement, depth: Int = 0) -> [String] {
        guard depth < 8 else { return [] }
        var role: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &role)
        if role as? String == kAXStaticTextRole {
            var value: CFTypeRef?
            AXUIElementCopyAttributeValue(element, kAXValueAttribute as CFString, &value)
            if let text = value as? String, !text.isEmpty { return [text] }
            return []
        }
        var children: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &children)
        return ((children as? [AXUIElement]) ?? []).flatMap { staticTexts(in: $0, depth: depth + 1) }
    }
}
