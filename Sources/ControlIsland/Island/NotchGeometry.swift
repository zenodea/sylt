import AppKit

struct NotchGeometry {
    let screen: NSScreen

    var hasNotch: Bool { screen.safeAreaInsets.top > 0 }

    var notchHeight: CGFloat {
        hasNotch ? screen.safeAreaInsets.top : screen.frame.maxY - screen.visibleFrame.maxY
    }

    var notchWidth: CGFloat {
        guard let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea else {
            return 180
        }
        return right.minX - left.maxX
    }

    static func preferredScreen() -> NSScreen? {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
    }
}
