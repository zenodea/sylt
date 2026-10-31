import AppKit

// AppKit honours NSCursor only for the frontmost app; SetsCursorInBackground lifts that.
enum CursorControl {
    private typealias ConnectionFn = @convention(c) () -> Int32
    private typealias SetPropertyFn = @convention(c) (Int32, Int32, CFString, CFTypeRef) -> Int32

    private static let backgroundAllowed: Bool = {
        let coreGraphics = PrivateFramework("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics")
        guard let connection = coreGraphics.symbol("CGSMainConnectionID", as: ConnectionFn.self),
              let setProperty = coreGraphics.symbol("CGSSetConnectionProperty", as: SetPropertyFn.self)
        else { return false }
        let cid = connection()
        return setProperty(cid, cid, "SetsCursorInBackground" as CFString, kCFBooleanTrue) == 0
    }()

    // Warping freezes mouse input for a moment unless this source exists with zero suppression.
    private static let eventSource: CGEventSource? = {
        let source = CGEventSource(stateID: .combinedSessionState)
        source?.localEventsSuppressionInterval = 0
        return source
    }()

    private static var hidden = false
    private static var display = CGMainDisplayID()

    static func warp(to point: CGPoint) {
        _ = eventSource
        let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
        CGWarpMouseCursorPosition(CGPoint(x: point.x, y: primaryHeight - point.y))
    }

    static func hide(on screen: NSScreen?) {
        guard !hidden else { return }
        hidden = true
        _ = backgroundAllowed
        display = screen?.displayID ?? CGMainDisplayID()
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
