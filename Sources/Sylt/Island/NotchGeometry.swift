import AppKit

/// The notch's size on a screen. With an auto-hiding menu bar macOS reports no notch at
/// all while the bar is away, and a screen change every time it slides, so the last
/// values that came from the real notch are remembered across launches and only
/// replaced by values that also come from it.
struct NotchGeometry: Equatable {
    let screen: NSScreen
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    /// True when these values came from the notch itself, now or on an earlier launch.
    let isMeasured: Bool

    private static let fallbackWidth: CGFloat = 180

    init(screen: NSScreen) {
        self.screen = screen
        let key = "notch.\(screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber ?? 0)"
        let height = screen.safeAreaInsets.top
        let width = screen.auxiliaryTopLeftArea.flatMap { left in screen.auxiliaryTopRightArea.map { $0.minX - left.maxX } }
        if height > 0, let width {
            UserDefaults.standard.set([width, height], forKey: key)
            (notchWidth, notchHeight, isMeasured) = (width, height, true)
        } else if let remembered = UserDefaults.standard.array(forKey: key) as? [CGFloat], remembered.count == 2 {
            (notchWidth, notchHeight, isMeasured) = (remembered[0], remembered[1], true)
        } else {
            (notchWidth, notchHeight, isMeasured) = (width ?? Self.fallbackWidth, height > 0 ? height : screen.frame.maxY - screen.visibleFrame.maxY, false)
        }
    }

    static func == (lhs: NotchGeometry, rhs: NotchGeometry) -> Bool {
        lhs.screen == rhs.screen && lhs.notchWidth == rhs.notchWidth && lhs.notchHeight == rhs.notchHeight && lhs.screen.frame == rhs.screen.frame
    }

    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 || $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main
    }
}
