import AppKit

// With an auto-hiding menu bar macOS reports no notch while the bar is away, and fires a
// screen change every time it slides, so values measured from the real notch (and the menu
// bar's overhang below it) are remembered across launches and only replaced by new measurements.
struct NotchGeometry: Equatable {
    let screen: NSScreen
    let notchWidth: CGFloat
    let notchHeight: CGFloat
    let menuBarOverhang: CGFloat
    let isMeasured: Bool
    /// False for a screen without a notch: an external display, or a built-in one seen with its menu bar up and no notch.
    let hasNotch: Bool
    /// The menu bar and the Dock, which a floating island keeps clear of.
    let insets: ScreenInsets

    private static let fallbackWidth: CGFloat = 180
    // More than this below the notch is the Dock or another inset, not the menu bar.
    private static let maxOverhang: CGFloat = 4

    init(screen: NSScreen) {
        self.screen = screen
        let display = screen.displayID ?? 0
        let key = "notch.\(display)"
        let height = screen.safeAreaInsets.top
        let width = screen.notchWidth
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        insets = ScreenInsets(
            // The menu bar may be hidden for now; the island stays clear of where it comes out.
            top: max(menuBar, NSStatusBar.system.thickness),
            left: screen.visibleFrame.minX - screen.frame.minX,
            bottom: screen.visibleFrame.minY - screen.frame.minY,
            right: screen.frame.maxX - screen.visibleFrame.maxX
        )
        if height > 0, let width {
            UserDefaults.standard.set([width, height], forKey: key)
            (notchWidth, notchHeight, isMeasured, hasNotch) = (width, height, true, true)
        } else if let remembered = UserDefaults.standard.array(forKey: key) as? [CGFloat], remembered.count == 2 {
            (notchWidth, notchHeight, isMeasured, hasNotch) = (remembered[0], remembered[1], true, true)
        } else if CGDisplayIsBuiltin(display) != 0, menuBar <= 0 {
            // A laptop's screen with the menu bar away may still have a notch: assume so until it can be measured.
            (notchWidth, notchHeight, isMeasured, hasNotch) = (width ?? Self.fallbackWidth, height > 0 ? height : menuBar, false, true)
        } else {
            (notchWidth, notchHeight, isMeasured, hasNotch) = (IslandLayout.notchlessGap, IslandLayout.notchlessHeight, true, false)
        }
        let overhangKey = "menuBarOverhang.\(display)"
        if !hasNotch {
            menuBarOverhang = 0
        } else if menuBar >= notchHeight, notchHeight > 0 {
            menuBarOverhang = min(menuBar - notchHeight, Self.maxOverhang)
            UserDefaults.standard.set(menuBarOverhang, forKey: overhangKey)
        } else {
            menuBarOverhang = UserDefaults.standard.object(forKey: overhangKey) as? CGFloat ?? 0
        }
    }

    static func == (lhs: NotchGeometry, rhs: NotchGeometry) -> Bool {
        lhs.screen == rhs.screen && lhs.notchWidth == rhs.notchWidth && lhs.notchHeight == rhs.notchHeight
            && lhs.menuBarOverhang == rhs.menuBarOverhang && lhs.screen.frame == rhs.screen.frame
            && lhs.hasNotch == rhs.hasNotch && lhs.insets == rhs.insets
    }

    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 || $0.auxiliaryTopLeftArea != nil } ?? NSScreen.main
    }
}
