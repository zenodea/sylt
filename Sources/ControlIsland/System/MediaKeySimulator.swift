import AppKit

/// Posts the same system-defined key events the keyboard's media keys produce,
/// so the frontmost player handles them. Needs Accessibility, like the interceptor.
enum MediaKeySimulator {
    enum Key: Int32 {
        case playPause = 16
        case next = 17
        case previous = 18
    }

    static func press(_ key: Key) {
        post(key, down: true)
        post(key, down: false)
    }

    private static func post(_ key: Key, down: Bool) {
        let flags: NSEvent.ModifierFlags = down ? [] : [.init(rawValue: 0xB00)]
        let data1 = Int(key.rawValue) << 16 | (down ? 0xA : 0xB) << 8
        guard let event = NSEvent.otherEvent(
            with: .systemDefined, location: .zero, modifierFlags: flags, timestamp: ProcessInfo.processInfo.systemUptime,
            windowNumber: 0, context: nil, subtype: 8, data1: data1, data2: -1
        ) else { return }
        event.cgEvent?.post(tap: .cghidEventTap)
    }
}
