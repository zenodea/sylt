import XCTest
@testable import Sylt

final class FormattingTests: XCTestCase {
    func testSwipeDirectionNeedsAThreshold() {
        XCTAssertNil(SwipeDirection(vector: CGVector(dx: 10, dy: 10)))
        XCTAssertEqual(SwipeDirection(vector: CGVector(dx: 0, dy: 60)), .down)
        XCTAssertEqual(SwipeDirection(vector: CGVector(dx: 0, dy: -60)), .up)
        XCTAssertEqual(SwipeDirection(vector: CGVector(dx: 70, dy: 20)), .right)
        XCTAssertEqual(SwipeDirection(vector: CGVector(dx: -70, dy: 20)), .left)
    }

    func testCalendarCountdownRoundsUp() {
        let now = Date()
        XCTAssertEqual(CalendarBadge.countdown(to: now.addingTimeInterval(241), now: now), "5m")
        XCTAssertEqual(CalendarBadge.countdown(to: now.addingTimeInterval(60), now: now), "1m")
        XCTAssertEqual(CalendarBadge.countdown(to: now.addingTimeInterval(-10), now: now), "now")
    }

    func testBatteryMessages() {
        XCTAssertEqual(BatteryAlert.powerSource.message(onAC: true), "Charging")
        XCTAssertEqual(BatteryAlert.powerSource.message(onAC: false), "On battery")
        XCTAssertEqual(BatteryAlert.level(100).message(onAC: false), "Fully charged")
        XCTAssertEqual(BatteryAlert.level(10).message(onAC: false), "Critically low")
        XCTAssertEqual(BatteryAlert.level(20).message(onAC: false), "Low battery")
        XCTAssertEqual(BatteryAlert.level(60).message(onAC: false), "Battery")
    }

    func testTitles() {
        XCTAssertEqual(NetworkMonitor.Link.offline.title, "Offline")
        XCTAssertEqual(ProcessInfo.ThermalState.critical.title, "Throttling")
    }

    func testTextWidthGrowsWithText() {
        XCTAssertLessThan(TextWidth.of("a", size: 11), TextWidth.of("abc", size: 11))
        XCTAssertEqual(TextWidth.widest(["a", "abc", "ab"], size: 11), TextWidth.of("abc", size: 11))
    }
}
