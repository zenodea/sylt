import AppKit
import Combine

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
    private static let retryInterval: TimeInterval = 2

    var isIntercepting: Bool { tap != nil }
    private var isActive: Bool { tap != nil || retryTimer != nil }

    func refreshAuthorization() {
        let trusted = AXIsProcessTrusted()
        if trusted != isAuthorized { isAuthorized = trusted }
        if trusted, retryTimer != nil { authorized() }
        // `isIntercepting` isn't published; the Settings pane re-reads it on this.
        objectWillChange.send()
    }

    func activate() {
        guard !isActive else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        isAuthorized = AXIsProcessTrustedWithOptions(options)
        Self.log("activate trusted=\(isAuthorized)")
        isAuthorized ? installTap() : scheduleRetry()
    }

    func deactivate() {
        stopRetrying()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        tap = nil
        source = nil
    }

    private func scheduleRetry() {
        retryTimer = .every(Self.retryInterval) { [weak self] in
            guard let self, AXIsProcessTrusted() else { return }
            isAuthorized = true
            authorized()
        }
    }

    private func authorized() {
        stopRetrying()
        installTap()
    }

    private func stopRetrying() {
        retryTimer?.invalidate()
        retryTimer = nil
    }

    // Only the HID tap sees keys before Control Center draws its own overlay.
    private func installTap() {
        let info = Unmanaged.passUnretained(self).toOpaque()
        let callback: CGEventTapCallBack = { _, type, event, info in
            guard let info else { return Unmanaged.passUnretained(event) }
            let interceptor = Unmanaged<MediaKeyInterceptor>.fromOpaque(info).takeUnretainedValue()
            return MainActor.assumeIsolated { interceptor.handle(type: type, event: event) }
        }
        let mask = CGEventMask(1 << Self.systemDefinedEvent.rawValue)
        let created = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: info)
            ?? CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: info)
        Self.log("trusted=\(AXIsProcessTrusted()) tap=\(created != nil)")
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
        Self.log("\(key) down=\(isKeyDown) handler=\(handler != nil)")
        if isKeyDown {
            let fine = nsEvent.modifierFlags.contains([.shift, .option])
            handler?(key, fine)
        }
        return nil
    }

    private static func log(_ message: String) {
        DebugLog.write("media keys: \(message)")
    }
}
