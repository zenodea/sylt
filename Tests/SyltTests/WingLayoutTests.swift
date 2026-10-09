import XCTest
@testable import Sylt

final class WingLayoutTests: XCTestCase {
    private let plugins = [WingPlugin(id: "agents", side: .left), WingPlugin(id: "weather", side: .right)]

    func testUntouchedLayoutIsNatural() {
        let wings = WingLayout().resolve(plugins: plugins)
        XCTAssertEqual(wings.left, [.calendar, .plugin("agents")])
        XCTAssertEqual(wings.right, [.privacy, .focus, .headphones, .plugin("weather"), .music])
    }

    func testMovingToTheOtherWingKeepsEverythingElseInPlace() {
        var layout = WingLayout()
        layout.move(.plugin("weather"), to: .left, before: .calendar, plugins: plugins)
        let wings = layout.resolve(plugins: plugins)
        XCTAssertEqual(wings.left, [.plugin("weather"), .calendar, .plugin("agents")])
        XCTAssertEqual(wings.right, [.privacy, .focus, .headphones, .music])
    }

    func testHiddenItemsNeverShow() {
        var layout = WingLayout()
        layout.move(.privacy, to: .hidden, plugins: plugins)
        let wings = layout.resolve(plugins: plugins)
        XCTAssertFalse(wings.left.contains(.privacy) || wings.right.contains(.privacy))
        XCTAssertEqual(layout.column(of: .privacy, plugins: plugins), .hidden)
    }

    func testUnknownPluginsFallIntoTheirNaturalWing() {
        var layout = WingLayout()
        layout.move(.focus, to: .left, plugins: plugins)
        let wings = layout.resolve(plugins: plugins + [WingPlugin(id: "timer", side: .left)])
        XCTAssertEqual(wings.left.last, .plugin("timer"))
    }

    func testRemovedPluginsAreDropped() {
        var layout = WingLayout()
        layout.move(.plugin("weather"), to: .left, plugins: plugins)
        let wings = layout.resolve(plugins: [plugins[0]])
        XCTAssertFalse(wings.left.contains(.plugin("weather")))
    }

    func testGapsRoundTripAndWidenTheWing() throws {
        var layout = WingLayout()
        layout.setGap(WingGap(spacing: 16, separator: true), between: .calendar, and: .plugin("agents"))
        let decoded = try JSONDecoder().decode(WingLayout.self, from: JSONEncoder().encode(layout))
        XCTAssertEqual(decoded, layout)
        XCTAssertEqual(decoded.resolve(plugins: plugins).gap(between: .calendar, and: .plugin("agents")).width, 17)

        var island = IslandLayout()
        island.showsCalendar = true
        island.pluginWidths = ["agents": 40]
        island.wings = layout.resolve(plugins: plugins)
        XCTAssertEqual(island.leftWing, CalendarBadge.width + 17 + 40 + IslandLayout.wingPadding * 2)
    }

    func testGapBelongsToTheItemInFrontOfIt() {
        var layout = WingLayout()
        layout.setGap(WingGap(spacing: 10), between: .calendar, and: .plugin("agents"))
        let wings = layout.resolve(plugins: plugins)
        XCTAssertEqual(wings.gap(between: .calendar, and: .plugin("timer")).spacing, 10, "the gap after the calendar holds whoever follows")
        XCTAssertEqual(wings.gap(between: .plugin("agents"), and: .calendar).spacing, 8)
    }

    func testOldPairKeyedGapsStillLoad() throws {
        let json = #"{"left":[],"right":[],"hidden":[],"gaps":{"calendar>plugin:agents":{"spacing":12,"separator":true}}}"#
        let layout = try JSONDecoder().decode(WingLayout.self, from: Data(json.utf8))
        XCTAssertEqual(layout.gap(between: .calendar, and: .music), WingGap(spacing: 12, separator: true))
    }
}
