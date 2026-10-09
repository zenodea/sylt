import XCTest
@testable import Sylt

final class MenuBarSettingsTests: XCTestCase {
    func testHidingModesRoundTripThroughTheTwoFlags() {
        for mode in MenuBarSettings.Hiding.allCases {
            XCTAssertEqual(MenuBarSettings.Hiding(hidesOnDesktop: mode.hidesOnDesktop, visibleInFullscreen: mode.visibleInFullscreen), mode)
        }
        XCTAssertEqual(MenuBarSettings.Hiding(hidesOnDesktop: false, visibleInFullscreen: false), .fullscreen, "what a fresh Mac does")
    }
}
