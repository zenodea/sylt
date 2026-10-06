import AppKit

/// The notch's size on a screen. An auto-hiding menu bar makes macOS report screen
/// changes every time it slides in or out, so the last values that came from the real
/// notch are kept and only replaced by values that also come from it.
struct NotchGeometry: Equatable {
    let screen: NSScreen
    let notchWidth: CGFloat
    let notchHeight: CGFloat

    nonisolated(unsafe) private static var known: [NSNumber: (width: CGFloat, height: CGFloat)] = [:]

    init(screen: NSScreen) {
        self.screen = screen
        let key = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber ?? 0
        let measuredHeight = screen.safeAreaInsets.top
        var measuredWidth: CGFloat?
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea { measuredWidth = right.minX - left.maxX }
        if measuredHeight > 0, let measuredWidth {
            Self.known[key] = (measuredWidth, measuredHeight)
        }
        if let known = Self.known[key] {
            notchWidth = known.width
            notchHeight = known.height
        } else {
            notchWidth = measuredWidth ?? 180
            notchHeight = measuredHeight > 0 ? measuredHeight : screen.frame.maxY - screen.visibleFrame.maxY
        }
    }

    var hasNotch: Bool { screen.safeAreaInsets.top > 0 }

    static func == (lhs: NotchGeometry, rhs: NotchGeometry) -> Bool {
        lhs.screen == rhs.screen && lhs.notchWidth == rhs.notchWidth && lhs.notchHeight == rhs.notchHeight && lhs.screen.frame == rhs.screen.frame
    }

    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}
