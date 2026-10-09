import XCTest
@testable import Sylt

final class IslandLayoutTests: XCTestCase {
    private var layout: IslandLayout {
        var layout = IslandLayout()
        layout.notchWidth = 180
        layout.notchHeight = 32
        return layout
    }

    func testPagesSpreadAcrossTheScreenWhenThereIsRoom() {
        var layout = layout
        layout.expandedPages = [[.media], [.event], [.plugin("a")], [.plugin("b")], [.plugin("c")]]
        layout.screenWidth = 1512
        XCTAssertEqual(layout.columns, 1, "off by default")
        layout.spreadsPages = true
        XCTAssertEqual(layout.columns, 2)
        XCTAssertEqual(layout.spreadCount, 3)
        XCTAssertEqual(layout.frame(for: .expanded, hovering: false).size.width, IslandLayout.expandedWidth * 2)
        layout.expandedPage = 3
        XCTAssertEqual(layout.currentSpread, 1)
        XCTAssertEqual(layout.currentSpreadPages, [[.plugin("a")], [.plugin("b")]])
        layout.screenWidth = 2560
        XCTAssertEqual(layout.columns, 3)
        layout.screenWidth = 1000
        XCTAssertEqual(layout.columns, 1, "no room to spare on a narrow screen")
        layout.screenWidth = 2560
        layout.expandedPages = [[.media]]
        XCTAssertEqual(layout.columns, 1, "never wider than the pages there are")
    }

    func testMenuBarItemsTakeTheirWidthOnlyWhenPlaced() {
        var layout = layout
        XCTAssertEqual(layout.rightWing, 0)
        layout.wings.right = [.wifi, .volume, .battery, .bluetooth]
        XCTAssertEqual(layout.rightWing, WiFiBadge.width + VolumeBadge.width + BatteryBadge.width + WingGap.defaultSpacing * 2 + IslandLayout.wingPadding * 2, "Bluetooth adds nothing while off")
        layout.bluetoothOn = true
        layout.hasBattery = false
        XCTAssertEqual(layout.visibleItems(layout.wings.right), [.wifi, .volume, .bluetooth])
    }

    func testEmptyWingsAddNothing() {
        let layout = layout
        XCTAssertEqual(layout.leftWing, 0)
        XCTAssertEqual(layout.rightWing, 0)
        XCTAssertEqual(layout.closedWidth, 180 + IslandLayout.sideOverlap * 2)
        XCTAssertEqual(layout.frame(for: .closed, hovering: false).centerOffset, 0)
    }

    func testWingsSizeIndependently() {
        var layout = layout
        layout.showsCalendar = true
        XCTAssertGreaterThan(layout.leftWing, 0)
        XCTAssertEqual(layout.rightWing, 0)
        let frame = layout.frame(for: .closed, hovering: false)
        XCTAssertEqual(frame.size.width, 180 + IslandLayout.sideOverlap * 2 + layout.leftWing)
        XCTAssertEqual(frame.centerOffset, -layout.leftWing / 2, "a left-only island shifts left to keep the notch covered")
    }

    func testRightOnlyHUDKeepsClosedLeftWing() {
        var layout = layout
        layout.pluginWidths = ["a": 40]
        layout.wings.left.append(.plugin("a"))
        let widths = layout.wingWidths(for: .hud(.volume))
        XCTAssertEqual(widths.leading, layout.leftWing)
        XCTAssertGreaterThan(widths.trailing, 0)
    }

    func testLeftOnlyHUDKeepsClosedRightWing() {
        var layout = layout
        layout.pluginWidths = ["a": 44]
        layout.wings.right.append(.plugin("a"))
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
        layout.pluginWidths = ["a": 48]
        layout.wings.left.append(.plugin("a"))
        let hit = layout.hitFrame(for: .closed, hovering: false)
        let island = layout.frame(for: .closed, hovering: false)
        XCTAssertEqual(hit.width, island.size.width + IslandLayout.hitMargin * 2)
        XCTAssertEqual(hit.minY, 0)
        XCTAssertTrue(hit.minX < layout.canvasSize.width / 2 && hit.maxX > layout.canvasSize.width / 2)
    }

    func testExpandedHeightStacksSections() {
        var layout = layout
        layout.expandedPages = ExpandedLayout().resolve(available: layout.availableSections)
        XCTAssertEqual(layout.expandedHeight, IslandLayout.expandedBaseHeight + IslandLayout.mediaCardHeight, "the media card is always there")
        layout.pluginSectionHeights = ["a": 34]
        layout.expandedPages = ExpandedLayout().resolve(available: layout.availableSections)
        XCTAssertEqual(
            layout.expandedHeight,
            IslandLayout.expandedBaseHeight + IslandLayout.mediaCardHeight + 34 + IslandLayout.sectionGap
        )
        XCTAssertLessThan(layout.expandedHeight, layout.canvasSize.height)
    }
}
