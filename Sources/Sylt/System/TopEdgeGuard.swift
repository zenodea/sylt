import AppKit

/// Keeps the pointer off the very top of the screen across the island, before macOS sees
/// it there and brings the menu bar out. A HID-level tap rewrites each mouse event's
/// position as it passes, so the cursor never lands on the edge at all.
@MainActor
final class TopEdgeGuard {
    static let shared = TopEdgeGuard()

    /// Screen x-range (CoreGraphics coordinates) under guard; empty disables it.
    nonisolated(unsafe) private static var span: ClosedRange<CGFloat>?
    private static let margin: CGFloat = 2
    private var tap: CFMachPort?

    func guardSpan(_ range: ClosedRange<CGFloat>?) {
        Self.span = range
        if range != nil, tap == nil { install() }
    }

    private func install() {
        let callback: CGEventTapCallBack = { _, type, event, _ in
            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                return Unmanaged.passUnretained(event)
            }
            guard let span = TopEdgeGuard.span else { return Unmanaged.passUnretained(event) }
            var location = event.location
            if location.y < TopEdgeGuard.margin, span.contains(location.x) {
                location.y = TopEdgeGuard.margin
                event.location = location
            }
            return Unmanaged.passUnretained(event)
        }
        let mask: CGEventMask = (1 << CGEventType.mouseMoved.rawValue) | (1 << CGEventType.leftMouseDragged.rawValue) | (1 << CGEventType.rightMouseDragged.rawValue)
        guard let created = CGEvent.tapCreate(tap: .cghidEventTap, place: .headInsertEventTap, options: .defaultTap, eventsOfInterest: mask, callback: callback, userInfo: nil) else { return }
        tap = created
        CFRunLoopAddSource(CFRunLoopGetMain(), CFMachPortCreateRunLoopSource(nil, created, 0), .commonModes)
        CGEvent.tapEnable(tap: created, enable: true)
    }
}
