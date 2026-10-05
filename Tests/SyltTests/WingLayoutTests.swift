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
}
