import XCTest
@testable import ControlIsland

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

    func testTimerClock() {
        XCTAssertEqual(TimerBadge.clock(0), "0:00")
        XCTAssertEqual(TimerBadge.clock(59.2), "1:00")
        XCTAssertEqual(TimerBadge.clock(1500), "25:00")
        XCTAssertEqual(TimerBadge.clock(3661), "1:01:01")
    }

    func testClipboardPreviewFlattensLines() {
        let item = ClipboardMonitor.Item(text: "  first\nsecond  ", date: .now)
        XCTAssertEqual(item.preview, "first second")
    }

    func testWeatherCodesMapToSymbols() {
        func report(_ code: Int) -> WeatherMonitor.Report { .init(temperature: 10, high: 12, low: 8, code: code, place: "") }
        XCTAssertEqual(report(0).symbol, "sun.max.fill")
        XCTAssertEqual(report(63).summary, "Rain")
        XCTAssertEqual(report(75).symbol, "cloud.snow.fill")
        XCTAssertEqual(report(95).summary, "Thunderstorm")
        XCTAssertEqual(report(999).summary, "Cloudy")
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
        let agent = HerdrAgent(agent: "codex", agent_status: "working", pane_id: "p", cwd: "/Users/me/project", focused: false, terminal_title_stripped: nil)
        XCTAssertEqual(agent.title, "project")
        XCTAssertEqual(agent.harness, .codex)
        XCTAssertTrue(agent.isWorking)
    }

    func testTextWidthGrowsWithText() {
        XCTAssertLessThan(TextWidth.of("a", size: 11), TextWidth.of("abc", size: 11))
        XCTAssertEqual(TextWidth.widest(["a", "abc", "ab"], size: 11), TextWidth.of("abc", size: 11))
    }

    func testDownloadPartialNames() {
        let names = ["report.pdf.crdownload", "song.mp3", "photo.jpg.download", "notes.txt.part", "done.zip"]
        XCTAssertEqual(DownloadsMonitor.partialNames(in: names), ["report.pdf", "photo.jpg", "notes.txt"])
    }
}
