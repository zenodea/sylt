import XCTest
@testable import Sylt

@MainActor
final class IslandStateTests: XCTestCase {
    private func makeState() -> IslandState {
        let defaults = scratchDefaults()
        return IslandState(preferences: Preferences(defaults: defaults), pluginStore: PluginStore(defaults: defaults))
    }

    func testHUDsRespectTheirSettingAndNeverInterruptTheOpenIsland() {
        let state = makeState()
        state.showHUD(.volume)
        XCTAssertEqual(state.mode, .hud(.volume))
        state.preferences.enabledHUDs.remove(.battery)
        state.showHUD(.battery(.powerSource))
        XCTAssertEqual(state.mode, .hud(.volume), "a switched-off overlay never shows")
        state.expand()
        state.showHUD(.volume)
        XCTAssertEqual(state.mode, .expanded)
    }

    func testHUDsDismissThemselvesUnlessHovered() {
        let state = makeState()
        state.preferences.hudDurationScale = 0.01
        state.showHUD(.capsLock(true))
        let closed = expectation(for: NSPredicate { _, _ in state.mode == .closed }, evaluatedWith: nil)
        wait(for: [closed], timeout: 2)

        state.showHUD(.capsLock(false))
        state.hoverChanged(true)
        let dismissed = expectation(for: NSPredicate { _, _ in state.mode == .closed }, evaluatedWith: nil)
        dismissed.isInverted = true
        wait(for: [dismissed], timeout: 0.2)
        XCTAssertEqual(state.mode, .hud(.capsLock(false)), "the pointer holds the overlay open")
    }

    func testSwipesOpenTurnAndClose() {
        let state = makeState()
        state.swiped(.left)
        XCTAssertEqual(state.mode, .closed, "nothing playing, nothing to skip")
        state.swiped(.down)
        XCTAssertEqual(state.mode, .expanded)
        state.layout.expandedPages = [[.media], [.event], [.plugin("a")]]
        state.swiped(.left)
        XCTAssertEqual(state.layout.expandedPage, 1)
        state.swiped(.right)
        state.swiped(.right)
        XCTAssertEqual(state.layout.expandedPage, 2, "turning back from the first page wraps to the last")
        state.swiped(.up)
        XCTAssertEqual(state.mode, .closed)
    }

    func testLeaningNeverPullsAnEdgeOffTheNotch() {
        let state = makeState()
        let rest = state.islandFrame
        for strength in [0.25, 1, 2] {
            state.preferences.swipeLeanStrength = strength
            for dx in [-IslandState.swipeReach, IslandState.swipeReach] {
                state.swipeMoved(CGVector(dx: dx, dy: 0))
                let leaned = state.islandFrame
                XCTAssertLessThanOrEqual(leaned.centerOffset - leaned.size.width / 2, rest.centerOffset - rest.size.width / 2, "left edge at \(strength), \(dx)")
                XCTAssertGreaterThanOrEqual(leaned.centerOffset + leaned.size.width / 2, rest.centerOffset + rest.size.width / 2, "right edge at \(strength), \(dx)")
            }
        }
        state.preferences.leansWithSwipes = false
        XCTAssertEqual(state.islandFrame, rest)
    }

    func testPushesLeaveThroughTheRimTheyPointAt() {
        let state = makeState()
        let island = state.layout.hitFrame(for: .closed, hovering: true).insetBy(dx: 1, dy: 1)
        let origin = CGPoint(x: island.midX, y: island.minY + 4)
        state.heldOrigin = origin
        XCTAssertEqual(state.rimPoint(toward: CGVector(dx: 0, dy: 10), outside: 0), CGPoint(x: origin.x, y: island.maxY))
        XCTAssertEqual(state.rimPoint(toward: CGVector(dx: 10, dy: 0), outside: 0).x, island.maxX, accuracy: 0.001)
        XCTAssertEqual(state.rimPoint(toward: CGVector(dx: 0, dy: -10), outside: 0), origin, "the screen's edge is above: pushing up goes nowhere")
        XCTAssertEqual(state.rimPoint(toward: CGVector(dx: 0, dy: 10), outside: 4).y, island.maxY + 4)
    }

    func testRimGlowsAsAFreePointerComesNear() {
        let state = makeState()
        let island = state.layout.hitFrame(for: .closed, hovering: false).insetBy(dx: IslandLayout.hitMargin, dy: 0)
        state.cursorApproached(CGPoint(x: island.midX, y: island.maxY + 7))
        XCTAssertEqual(state.approachStrength, 0.9, accuracy: 0.001)
        XCTAssertEqual(state.approachPoint, CGPoint(x: island.midX, y: island.maxY))
        state.cursorApproached(CGPoint(x: island.midX, y: island.maxY + IslandState.approachReach + 1))
        XCTAssertEqual(state.approachStrength, 0)
    }
}
