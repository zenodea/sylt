import AppKit
import Combine

/// Swallows the hardware volume and brightness keys so macOS never shows its
/// own overlay, and reports them so the island can apply the change itself.
@MainActor
final class MediaKeyInterceptor: ObservableObject {
    enum Key: Int32 {
        case volumeUp = 0
        case volumeDown = 1
        case brightnessUp = 2
        case brightnessDown = 3
        case mute = 7
    }

    @Published private(set) var isAuthorized = false
    var handler: ((Key, _ fine: Bool) -> Void)?

    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var retryTimer: Timer?
    private static let systemDefinedEvent = CGEventType(rawValue: 14)!
    private static let auxiliaryControlSubtype: Int16 = 8

    var isActive: Bool { tap != nil || retryTimer != nil }

    func activate() {
        guard !isActive else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        isAuthorized = AXIsProcessTrustedWithOptions(options)
        isAuthorized ? installTap() : scheduleRetry()
    }

    func deactivate() {
        retryTimer?.invalidate()
        retryTimer = nil
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    static func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
    }

    private func scheduleRetry() {
        retryTimer = .scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, AXIsProcessTrusted() else { return }
                self.retryTimer?.invalidate()
                self.retryTimer = nil
                self.isAuthorized = true
                self.installTap()
            }
        }
    }

    private func installTap() {
        let info = Unmanaged.passUnretained(self).toOpaque()
        let created = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(1 << Self.systemDefinedEvent.rawValue),
            callback: { _, type, event, info in
                guard let info else { return Unmanaged.passUnretained(event) }
                let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(info).takeUnretainedValue()
                return MainActor.assumeIsolated { interceptor.handle(type: type, event: event) }
            },
            userInfo: info
        )
        guard let created else {
            isAuthorized = false
            scheduleRetry()
            return
        }
        tap = created
        source = CFMachPortCreateRunLoopSource(nil, created, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == Self.systemDefinedEvent,
              let nsEvent = NSEvent(cgEvent: event),
              nsEvent.subtype.rawValue == Self.auxiliaryControlSubtype,
              let key = Key(rawValue: Int32((nsEvent.data1 & 0xFFFF_0000) >> 16))
        else { return Unmanaged.passUnretained(event) }

        let flags = nsEvent.data1 & 0xFFFF
        let isKeyDown = (flags & 0xFF00) >> 8 == 0xA
        if isKeyDown {
            let fine = nsEvent.modifierFlags.contains([.shift, .option])
            handler?(key, fine)
        }
        return nil
    }
}
