import XCTest
@testable import Sylt

@MainActor
final class MonitorLogicTests: XCTestCase {
    private func battery(_ percent: Int, onAC: Bool = false, charging: Bool = false) -> BatterySnapshot {
        BatterySnapshot(percent: percent, isCharging: charging, onAC: onAC)
    }

    func testBatteryAlertsOnTheChargerAndFullCharge() {
        XCTAssertEqual(BatteryMonitor.alert(from: battery(50, onAC: true), to: battery(50)), .powerSource)
        XCTAssertEqual(BatteryMonitor.alert(from: battery(50), to: battery(50, onAC: true, charging: true)), .powerSource)
        XCTAssertEqual(BatteryMonitor.alert(from: battery(99, onAC: true, charging: true), to: battery(100, onAC: true, charging: true)), .level(100))
        XCTAssertNil(BatteryMonitor.alert(from: battery(100, onAC: true, charging: true), to: battery(100, onAC: true, charging: true)))
    }

    func testBatteryAlertsOnceForEachThresholdCrossedDischarging() {
        XCTAssertEqual(BatteryMonitor.alert(from: battery(21), to: battery(20)), .level(20))
        XCTAssertNil(BatteryMonitor.alert(from: battery(20), to: battery(19)), "already past 20")
        XCTAssertEqual(BatteryMonitor.alert(from: battery(16), to: battery(9)), .level(15), "a jump reports the first threshold it crossed")
        XCTAssertNil(BatteryMonitor.alert(from: battery(19, onAC: true, charging: true), to: battery(21, onAC: true, charging: true)))
        XCTAssertNil(BatteryMonitor.alert(from: battery(50), to: BatterySnapshot(hasBattery: false)))
    }

    func testBluetoothWarnsAtTwentyThenTenAndStartsOverAfterCharging() {
        var warnings = LowBatteryWarnings()
        let levels = [50, 20, 18, 10, 5, 30, 19]
        let warned = levels.map { warnings.shouldWarn("mouse", level: $0) }
        XCTAssertEqual(warned, [false, true, false, true, false, false, true])
        XCTAssertTrue(warnings.shouldWarn("keyboard", level: 9), "each device counts on its own")
        warnings.forget("mouse")
        XCTAssertTrue(warnings.shouldWarn("mouse", level: 15), "a reconnected device warns again")
    }

    func testCalendarFindsTheVideoCallLink() {
        let notes = "Agenda attached.\nJoin: https://us02web.zoom.us/j/123?pwd=abc"
        XCTAssertEqual(CalendarMonitor.joinURL(in: [nil, "Room 4", notes])?.host, "us02web.zoom.us")
        XCTAssertEqual(CalendarMonitor.joinURL(in: ["https://meet.google.com/abc-defg-hij"])?.absoluteString, "https://meet.google.com/abc-defg-hij")
        XCTAssertNil(CalendarMonitor.joinURL(in: ["https://example.com/zoom.us", "https://fakezoom.us/j/1"]), "only the real hosts count")
        XCTAssertNil(CalendarMonitor.joinURL(in: [nil, nil]))
    }

    func testFocusNamesTheActiveMode() {
        let assertions: [String: Any] = ["data": [["storeAssertionRecords": [["assertionDetails": ["assertionDetailsModeIdentifier": "com.apple.focus.work"]]]]]]
        let configurations: [String: Any] = ["data": [["modeConfigurations": ["com.apple.focus.work": ["mode": ["name": "Deep work"]]]]]]
        XCTAssertEqual(FocusMonitor.activeMode(assertions: assertions, configurations: configurations), "Deep work")
        XCTAssertEqual(FocusMonitor.activeMode(assertions: assertions, configurations: nil), "work", "the identifier stands in for a missing name")
        XCTAssertNil(FocusMonitor.activeMode(assertions: ["data": [["storeAssertionRecords": []]]], configurations: configurations))
        XCTAssertNil(FocusMonitor.activeMode(assertions: nil, configurations: configurations))
    }

    func testPrivacyMessageNamesTheRecordingApp() {
        XCTAssertEqual(PrivacyMonitor.Use(microphone: true, microphoneApp: "Zoom").message, "Microphone on · Zoom")
        XCTAssertEqual(PrivacyMonitor.Use(microphone: true, camera: true).message, "Mic and camera on")
        XCTAssertEqual(PrivacyMonitor.Use(camera: true, microphoneApp: "Zoom").message, "Camera on")
        XCTAssertEqual(PrivacyMonitor.Use().message, "Mic and camera off")
    }
}
