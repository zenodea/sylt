import XCTest
@testable import Sylt

final class IslandPlacementTests: XCTestCase {
    private let screen = CGSize(width: 2560, height: 1440)
    private let insets = ScreenInsets(top: 24, left: 0, bottom: 70, right: 0)
    private let gap = IslandLayout.floatingGap

    private func notchless(_ placement: IslandPlacement) -> IslandLayout {
        var layout = IslandLayout()
        layout.hasNotch = false
        layout.notchWidth = IslandLayout.notchlessGap
        layout.notchHeight = IslandLayout.notchlessHeight
        layout.screenSize = screen
        layout.screenInsets = insets
        layout.screenWidth = screen.width
        layout.placement = placement
        layout.wings.left = [.wifi]
        layout.wings.right = [.volume]
        return layout
    }

    func testThePointerSnapsIntoCornersAndToTheMiddleOfAnEdge() {
        XCTAssertEqual(IslandPlacement.nearest(to: CGPoint(x: 2540, y: 10), in: screen), IslandPlacement(edge: .top, position: 1))
        XCTAssertEqual(IslandPlacement.nearest(to: CGPoint(x: 30, y: 1400), in: screen), IslandPlacement(edge: .bottom, position: 0))
        XCTAssertEqual(IslandPlacement.nearest(to: CGPoint(x: 1290, y: 4), in: screen), .standard, "within reach of the middle it centres exactly")
        let along = IslandPlacement.nearest(to: CGPoint(x: 640, y: 4), in: screen)
        XCTAssertEqual(along.edge, .top)
        XCTAssertEqual(along.position, 0.25, accuracy: 0.001)
        XCTAssertFalse(along.isCorner)
        let side = IslandPlacement.nearest(to: CGPoint(x: 6, y: 300), in: screen)
        XCTAssertEqual(side.edge, .left, "the nearest edge wins")
        XCTAssertFalse(side.isCorner)
        let close = IslandPlacement.nearest(to: CGPoint(x: 400, y: 1430), in: screen)
        XCTAssertEqual(close.edge, .bottom)
        XCTAssertGreaterThan(close.position, 0, "short of a corner it still floats")
    }

    func testEachCornerHasOneSpelling() {
        XCTAssertEqual(IslandPlacement(edge: .left, position: 0), IslandPlacement(edge: .top, position: 0))
        XCTAssertEqual(IslandPlacement(edge: .right, position: 1), IslandPlacement(edge: .bottom, position: 1))
        XCTAssertTrue(IslandPlacement(edge: .right, position: 0).isCorner)
        XCTAssertEqual(IslandPlacement(edge: .top, position: 2).position, 1, "positions stay on the edge")
    }

    func testACornerIslandIsFlushAndGrowsAwayFromIt() {
        let layout = notchless(IslandPlacement(edge: .top, position: 1))
        let closed = layout.rect(of: layout.frame(for: .closed, hovering: false))
        XCTAssertEqual(closed.maxX, screen.width)
        XCTAssertEqual(closed.minY, 0)
        XCTAssertEqual(layout.anchor.flush, [.top, .trailing])
        let open = layout.rect(of: layout.frame(for: .expanded, hovering: false))
        XCTAssertEqual(open.maxX, screen.width, "the side on the screen's edge never moves")
        XCTAssertEqual(open.minY, 0)

        let bottomLeft = notchless(IslandPlacement(edge: .bottom, position: 0))
        let corner = bottomLeft.rect(of: bottomLeft.frame(for: .expanded, hovering: false))
        XCTAssertEqual(corner.minX, 0)
        XCTAssertEqual(corner.maxY, screen.height, "a corner ignores the Dock: it is the screen's corner")
    }

    func testAFloatingIslandKeepsClearOfTheMenuBarAndTheDock() {
        let top = notchless(.standard)
        let closed = top.rect(of: top.frame(for: .closed, hovering: false))
        XCTAssertEqual(closed.minY, insets.top + gap)
        XCTAssertEqual(closed.midX, screen.width / 2, accuracy: 0.5)
        XCTAssertTrue(top.anchor.isFloating)

        let bottom = notchless(IslandPlacement(edge: .bottom, position: 0.5))
        let open = bottom.rect(of: bottom.frame(for: .expanded, hovering: false))
        XCTAssertEqual(open.maxY, screen.height - insets.bottom - gap, "it opens upward from above the Dock")

        let nearCorner = notchless(IslandPlacement(edge: .top, position: 0.999))
        let wide = nearCorner.rect(of: nearCorner.frame(for: .expanded, hovering: false))
        XCTAssertEqual(wide.maxX, screen.width - gap, "it never goes off screen")

        let right = notchless(IslandPlacement(edge: .right, position: 0.5))
        let side = right.rect(of: right.frame(for: .closed, hovering: false))
        XCTAssertEqual(side.maxX, screen.width - gap)
        XCTAssertEqual(side.midY, screen.height / 2, accuracy: 0.5)
    }

    func testWithoutANotchTheIslandOwnsTheScreenAndDropsTheNotchBand() {
        let layout = notchless(.standard)
        XCTAssertEqual(layout.canvasSize, screen)
        XCTAssertEqual(layout.overlap, 0)
        XCTAssertEqual(layout.expandedHeader, IslandLayout.floatingHeader)
        var notched = IslandLayout()
        notched.notchHeight = 32
        var bare = notched
        bare.hasNotch = false
        bare.notchHeight = IslandLayout.notchlessHeight
        XCTAssertLessThan(bare.expandedHeight, notched.expandedHeight, "no empty band where a notch would be")
        let home = layout.expandedHome
        let open = layout.rect(of: layout.frame(for: .expanded, hovering: false))
        XCTAssertTrue(open.contains(home))
    }

    func testHitFramesAndWingItemsFollowTheIsland() {
        for placement in IslandPlacement.targets {
            let layout = notchless(placement)
            let island = layout.rect(of: layout.frame(for: .closed, hovering: false))
            let hit = layout.hitFrame(for: .closed, hovering: false)
            XCTAssertTrue(hit.contains(CGPoint(x: island.midX, y: island.midY)), "\(placement)")
            XCTAssertTrue(CGRect(origin: .zero, size: screen).contains(hit.insetBy(dx: 0.5, dy: 0.5)), "\(placement) stays on screen")
            XCTAssertEqual(layout.item(at: island.minX + IslandLayout.wingPadding + 2), .wifi, "\(placement)")
            XCTAssertEqual(layout.item(at: island.maxX - IslandLayout.wingPadding - 2), .volume, "\(placement)")
            let hovered = layout.rect(of: layout.frame(for: .closed, hovering: true))
            XCTAssertEqual(layout.item(at: hovered.maxX - IslandLayout.hoverGrowth.width / 2 - IslandLayout.wingPadding - 2, hovering: true), .volume, "\(placement) while hovered")
        }
    }

    func testOnlyPushesAwayFromTheScreensEdgeCount() {
        let up = CGVector(dx: 0, dy: -10), right = CGVector(dx: 10, dy: 0), down = CGVector(dx: 0, dy: 10)
        XCTAssertFalse(up.pushes(away: .top), "under a notch, up is into the screen's edge")
        XCTAssertTrue(down.pushes(away: .top))
        XCTAssertTrue(up.pushes(away: []), "a floating island lets go in any direction")
        XCTAssertFalse(right.pushes(away: [.top, .trailing]))
        XCTAssertEqual(CGVector(dx: 5, dy: -5).push(away: [.top, .trailing]), .zero)
        XCTAssertEqual(CGVector(dx: -5, dy: 5).push(away: [.top, .trailing]), CGVector(dx: -5, dy: 5))
    }

    func testTheOutlineLeavesOutOnlyTheSidesOnTheScreensEdge() {
        let frame = IslandFrame(size: CGSize(width: 200, height: 30), centerOffset: 0)
        let canvas = CGRect(origin: .zero, size: screen)
        let floating = IslandShape(frame: frame, origin: CGPoint(x: 100, y: 100), flush: [], radius: 15).outline(in: canvas, step: 2)
        XCTAssertTrue(floating.contains { $0.normal.dy < -0.99 }, "a floating island has a top")
        XCTAssertTrue(floating.contains { $0.normal.dx > 0.99 } && floating.contains { $0.normal.dx < -0.99 } && floating.contains { $0.normal.dy > 0.99 })
        let notch = IslandShape(frame: frame, origin: CGPoint(x: 100, y: 0), flush: .top, radius: 10).outline(in: canvas, step: 2)
        XCTAssertFalse(notch.contains { $0.normal.dy < -0.01 }, "nothing faces up into the notch")
        XCTAssertEqual(notch.first?.point, CGPoint(x: 100, y: 0), "it starts at the top-left, as the ripple expects")
        let corner = IslandShape(frame: frame, origin: CGPoint(x: screen.width - 200, y: 0), flush: [.top, .trailing], radius: 15).outline(in: canvas, step: 2)
        XCTAssertFalse(corner.contains { $0.point.x > screen.width - 0.5 && abs($0.normal.dx - 1) < 0.01 }, "nothing faces off screen")
        XCTAssertTrue(corner.contains { $0.normal.dx < -0.99 } && corner.contains { $0.normal.dy > 0.99 })
    }

    func testRippledCornerIslandsCloseAlongTheScreensEdge() {
        let frame = IslandFrame(size: CGSize(width: 200, height: 30), centerOffset: 0)
        let canvas = CGRect(origin: .zero, size: screen)
        let shape = IslandShape(frame: frame, origin: CGPoint(x: screen.width - 200, y: screen.height - 30), flush: [.bottom, .trailing], radius: 15)
        let outline = shape.outline(in: canvas, step: 1, includingEdges: true)
        let gaps = zip(outline, outline.dropFirst()).map { hypot($1.point.x - $0.point.x, $1.point.y - $0.point.y) }
        XCTAssertLessThan(gaps.max() ?? 0, 2, "the closed outline runs along the screen's edge instead of cutting across")
        XCTAssertTrue(outline.contains { $0.normal == .zero }, "the sides on the edge don't move")
    }
}

@MainActor
final class IslandMoveTests: XCTestCase {
    private func makeState(notch: Bool) -> IslandState {
        let defaults = scratchDefaults()
        let state = IslandState(preferences: Preferences(defaults: defaults), pluginStore: PluginStore(defaults: defaults))
        state.layout.hasNotch = notch
        state.layout.screenSize = CGSize(width: 1920, height: 1080)
        state.layout.screenInsets = ScreenInsets(top: 24)
        return state
    }

    func testCommandDragMovesTheIslandAndRemembersWhereItLanded() {
        let state = makeState(notch: false)
        XCTAssertTrue(state.canMove)
        state.beginMove()
        XCTAssertTrue(state.isMoving)
        XCTAssertFalse(state.absorbsCursor, "the pointer stays free while moving")
        state.move(to: CGPoint(x: 1910, y: 1070))
        XCTAssertEqual(state.layout.placement, IslandPlacement(edge: .bottom, position: 1))
        XCTAssertEqual(state.preferences.placement, .standard, "saved only once it is let go")
        state.endMove()
        XCTAssertFalse(state.isMoving)
        XCTAssertEqual(state.preferences.placement, IslandPlacement(edge: .bottom, position: 1))
        state.released()
        XCTAssertEqual(state.mode, .closed, "the mouse-up that ends a move doesn't open the island")
    }

    func testTheNotchIslandStaysPut() {
        let state = makeState(notch: true)
        XCTAssertFalse(state.canMove)
        state.beginMove()
        XCTAssertFalse(state.isMoving)
        state.move(to: CGPoint(x: 10, y: 1000))
        XCTAssertEqual(state.layout.placement, .standard)
    }

    func testRimPointsFollowPushesInAnyDirectionWhenFloating() {
        let state = makeState(notch: false)
        state.layout.placement = IslandPlacement(edge: .bottom, position: 0.5)
        let island = state.layout.hitFrame(for: .closed, hovering: true).insetBy(dx: 1, dy: 1)
        XCTAssertEqual(state.rimPoint(toward: CGVector(dx: 0, dy: -10), outside: 0).y, island.minY, accuracy: 0.01, "up and out of an island on the bottom edge")
        state.layout.placement = IslandPlacement(edge: .bottom, position: 1)
        XCTAssertFalse(state.pushes(CGVector(dx: 0, dy: 10)), "a bottom corner can't be pushed down into the edge")
        XCTAssertTrue(state.pushes(CGVector(dx: -10, dy: 0)))
    }
}

@MainActor
final class PlacementPreferenceTests: XCTestCase {
    func testThePlacementIsRemembered() {
        let defaults = scratchDefaults()
        let preferences = Preferences(defaults: defaults)
        XCTAssertEqual(preferences.placement, .standard)
        preferences.placement = IslandPlacement(edge: .left, position: 0.3)
        XCTAssertEqual(Preferences(defaults: defaults).placement, IslandPlacement(edge: .left, position: 0.3))
    }
}
