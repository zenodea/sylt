import XCTest
@testable import ControlIsland

final class IslandLayoutTests: XCTestCase {
    private var layout: IslandLayout {
        var layout = IslandLayout()
        layout.notchWidth = 180
        layout.notchHeight = 32
        return layout
    }

    func testEmptyWingsAddNothing() {
        let layout = layout
        XCTAssertEqual(layout.leftWing, 0)
        XCTAssertEqual(layout.rightWing, 0)
        XCTAssertEqual(layout.closedWidth, 180)
        XCTAssertEqual(layout.frame(for: .closed, hovering: false).centerOffset, 0)
    }

    func testWingsSizeIndependently() {
        var layout = layout
        layout.showsCalendar = true
        XCTAssertGreaterThan(layout.leftWing, 0)
        XCTAssertEqual(layout.rightWing, 0)
        let frame = layout.frame(for: .closed, hovering: false)
        XCTAssertEqual(frame.size.width, 180 + layout.leftWing)
        XCTAssertEqual(frame.centerOffset, -layout.leftWing / 2, "a left-only island shifts left to keep the notch covered")
    }

    func testRightOnlyHUDKeepsClosedLeftWing() {
        var layout = layout
        layout.pluginLeft = [40]
        let widths = layout.wingWidths(for: .hud(.volume))
        XCTAssertEqual(widths.leading, layout.leftWing)
        XCTAssertGreaterThan(widths.trailing, 0)
    }

    func testLeftOnlyHUDKeepsClosedRightWing() {
        var layout = layout
        layout.pluginRight = [44]
        let hud = ExternalHUD(pluginID: "agents", hud: PluginHUD(symbol: "checkmark.circle.fill", text: "Done", side: "left"))
        let widths = layout.wingWidths(for: .hud(.external(hud)))
        XCTAssertEqual(widths.trailing, layout.rightWing)
        XCTAssertGreaterThan(widths.leading, 0)
    }

    func testHoverGrowsEverythingButExpanded() {
        let layout = layout
        let closed = layout.frame(for: .closed, hovering: true).size
        XCTAssertEqual(closed.width, layout.closedWidth + IslandLayout.hoverGrowth.width)
        XCTAssertEqual(closed.height, 32 + IslandLayout.hoverGrowth.height)
        let expanded = layout.frame(for: .expanded, hovering: true).size
        XCTAssertEqual(expanded, layout.frame(for: .expanded, hovering: false).size)
    }

    func testTrackHUDKeepsClosedWidthAndAddsRow() {
        var layout = layout
        layout.showsArtwork = true
        let frame = layout.frame(for: .hud(.nowPlaying), hovering: false)
        XCTAssertEqual(frame.size.width, layout.closedWidth)
        XCTAssertGreaterThan(frame.size.height, 32)
    }

    func testHitFrameContainsIsland() {
        var layout = layout
        layout.pluginLeft = [48]
        let hit = layout.hitFrame(for: .closed, hovering: false)
        let island = layout.frame(for: .closed, hovering: false)
        XCTAssertEqual(hit.width, island.size.width + IslandLayout.hitMargin * 2)
        XCTAssertEqual(hit.minY, 0)
        XCTAssertTrue(hit.minX < layout.canvasSize.width / 2 && hit.maxX > layout.canvasSize.width / 2)
    }

    func testExpandedHeightStacksSections() {
        var layout = layout
        XCTAssertEqual(layout.expandedHeight, IslandLayout.expandedBaseHeight + IslandLayout.emptyExpandedHeight)
        layout.showsMediaCard = true
        layout.pluginSections = [34]
        XCTAssertEqual(
            layout.expandedHeight,
            IslandLayout.expandedBaseHeight + IslandLayout.mediaCardHeight + 34 + IslandLayout.sectionGap
        )
        XCTAssertLessThan(layout.expandedHeight, layout.canvasSize.height)
    }
}
