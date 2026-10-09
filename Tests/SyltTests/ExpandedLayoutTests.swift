import XCTest
@testable import Sylt

final class ExpandedLayoutTests: XCTestCase {
    private let all: [ExpandedSection] = [.media, .event, .plugin("timer"), .plugin("weather"), .plugin("agents")]

    func testUntouchedLayoutDealsTwoPerPage() {
        let pages = ExpandedLayout().resolve(available: all)
        XCTAssertEqual(pages, [[.media, .event], [.plugin("timer"), .plugin("weather")], [.plugin("agents")]])
    }

    func testMissingSectionsDropOutAndEmptyPagesVanish() {
        var layout = ExpandedLayout()
        layout.pages = [["media"], ["plugin:timer"], ["event"]]
        let pages = layout.resolve(available: [.media, .event])
        XCTAssertEqual(pages, [[.media], [.event]])
    }

    func testMovingToANewPageKeepsTheRestInPlace() {
        var layout = ExpandedLayout()
        layout.move(.plugin("agents"), toPage: 3, all: all)
        XCTAssertEqual(layout.resolve(available: all), [[.media, .event], [.plugin("timer"), .plugin("weather")], [.plugin("agents")]])
        layout.move(.event, toPage: 1, before: .plugin("timer"), all: all)
        XCTAssertEqual(layout.resolve(available: all), [[.media], [.event, .plugin("timer"), .plugin("weather")], [.plugin("agents")]])
    }

    func testHeightIsTheTallestPageOnEveryPage() {
        var layout = IslandLayout()
        layout.showsMediaCard = true
        layout.pluginSectionHeights = ["a": 40, "b": 50]
        layout.expandedPages = ExpandedLayout().resolve(available: layout.availableSections)
        XCTAssertEqual(layout.expandedPages.count, 2)
        let first = layout.expandedHeight
        layout.expandedPage = 1
        XCTAssertEqual(layout.expandedHeight, first)
        XCTAssertEqual(layout.currentSpreadPages, [[.plugin("b")]])
        XCTAssertEqual(first, IslandLayout.expandedBaseHeight + 138 + IslandLayout.sectionGap + 40 + IslandLayout.pageDotsHeight)
    }

    func testWholePagesMove() {
        var layout = ExpandedLayout()
        layout.movePage(2, by: -1, all: all)
        XCTAssertEqual(layout.resolve(available: all), [[.media, .event], [.plugin("agents")], [.plugin("timer"), .plugin("weather")]])
        layout.movePage(0, by: -1, all: all)
        XCTAssertEqual(layout.resolve(available: all).first, [.media, .event], "the first page can't move earlier")
    }
}
