import AppKit

/// Hides, shows and moves the pointer from a background app. AppKit only honours
/// NSCursor for the frontmost app, so this asks WindowServer for permission to set
/// the cursor from the background and then hides it at the display level.
enum CursorControl {
    private typealias ConnectionFn = @convention(c) () -> Int32
    private typealias SetPropertyFn = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private static let backgroundAllowed: Bool = {
        guard let handle = dlopen("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics", RTLD_NOW),
              let connection = dlsym(handle, "CGSMainConnectionID"),
              let setProperty = dlsym(handle, "CGSSetConnectionProperty")
        else { return false }
        let cid = unsafeBitCast(connection, to: ConnectionFn.self)()
        let set = unsafeBitCast(setProperty, to: SetPropertyFn.self)
        return set(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue) == 0
    }()

    /// Warping the pointer normally freezes mouse input for a moment; this source doesn't.
    private static let eventSource: CGEventSource? = {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0
        return source
    }()

    private static var hidden = false
    private static var display = CGMainDisplayID()

    /// Moves the pointer to a Cocoa screen point (bottom-left origin of the primary display).
    static func warp(to point: CGPoint) {
        _ = eventSource
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        CGWarpMouseCursorPosition(CGPoint(x: point.x, y: primaryHeight - point.y))
    }

    static func hide(on screen: NSScreen?) {
        guard !hidden else { return }
        hidden = true
        _ = backgroundAllowed
        display = (screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID) ?? CGMainDisplayID()
        CGDisplayHideCursor(display)
        NSCursor.hide()
    }

    static func show() {
        guard hidden else { return }
        hidden = false
        CGDisplayShowCursor(display)
        NSCursor.unhide()
    }
}
