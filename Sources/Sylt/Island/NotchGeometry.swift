import AppKit

/// The notch's size on a screen. With an auto-hiding menu bar macOS reports no notch at
/// all while the bar is away, and a screen change every time it slides, so the last
/// values that came from the real notch are kept, remembered across launches, and only
/// replaced by values that also come from it.
struct NotchGeometry: Equatable {
    let screen: NSScreen
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    /// True when these values came from the notch itself, now or on an earlier launch.
    let isMeasured: Bool

    init(screen: NSScreen) {
        self.screen = screen
        let key = "notch.\(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber ?? 0)"
        let measuredHeight = screen.safeAreaInsets.top
        var measuredWidth: CGFloat?
        if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea { measuredWidth = right.minX - left.maxX }
        if measuredHeight > 0, let measuredWidth {
            UserDefaults.standard.set([measuredWidth, measuredHeight], forKey: key)
        }
        if let remembered = UserDefaults.standard.array(forKey: key) as? [CGFloat], remembered.count == 2 {
            notchWidth = remembered[0]
            notchHeight = remembered[1]
            isMeasured = true
        } else {
            notchWidth = measuredWidth ?? 180
            notchHeight = measuredHeight > 0 ? measuredHeight : screen.frame.maxY - screen.visibleFrame.maxY
            isMeasured = false
        }
    }

    var hasNotch: Bool { screen.safeAreaInsets.top > 0 }

    static func == (lhs: NotchGeometry, rhs: NotchGeometry) -> Bool {
        lhs.screen == rhs.screen && lhs.notchWidth == rhs.notchWidth && lhs.notchHeight == rhs.notchHeight && lhs.screen.frame == rhs.screen.frame
    }

    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 || $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main
    }
}
