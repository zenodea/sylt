import XCTest
@testable import ControlIsland

final class HUDKindTests: XCTestCase {
    private let samples: [HUDKind] = [
        .volume, .brightness, .mute(true), .battery(.level(15)), .battery(.powerSource),
        .agentFinished(HerdrAgent(agent: "claude", agent_status: "idle", pane_id: "p", cwd: "/tmp/x", focused: false, terminal_title_stripped: "A long title that will need truncation somewhere")),
        .unlocked, .nowPlaying,
        .notification(SystemNotification(appName: "Messages", title: "Hi", body: "There", bundleIdentifier: nil)),
        .bluetooth(.connected(.init(name: "AirPods", address: "a", battery: 50))),
        .peripheralBattery(.init(name: "Mouse", address: "b", battery: 9)),
        .network(.wifi), .calendar(.init(id: "e", title: "Standup", start: .now, end: .now, joinURL: nil)),
        .timerDone(1500), .capsLock(true), .inputSource("British"), .focus("Work"), .privacy(.init(microphone: true)),
        .download(.started("file")), .thermal(.serious),
    ]

    func testEveryKindHasPositiveDurationAndAWing() {
        for kind in samples {
            XCTAssertGreaterThan(kind.duration, 0, "\(kind)")
            switch kind.style {
            case .compact(let leading, let trailing):
                XCTAssertTrue((leading ?? 0) > 0 || (trailing ?? 0) > 0, "\(kind) claims no wing")
            case .twoRow, .card:
                break
            }
        }
    }

    func testLevelHUDsLeaveTheLeftWingAlone() {
        for kind in [HUDKind.volume, .brightness, .mute(false), .capsLock(false), .inputSource("US")] {
            guard case .compact(let leading, let trailing) = kind.style else { return XCTFail("\(kind) is not compact") }
            XCTAssertNil(leading)
            XCTAssertNotNil(trailing)
        }
    }

    func testNetworkLabelsShareOneWidth() {
        let widths = NetworkMonitor.Link.allCases.map { link -> Double? in
            if case .compact(_, let trailing) = HUDKind.network(link).style { return trailing }
            return nil
        }
        XCTAssertEqual(Set(widths.compactMap { $0 }).count, 1)
    }

    func testBatteryMessagesShareOneWidth() {
        let widths = [BatteryAlert.level(5), .level(15), .level(100), .powerSource].map { alert -> Double? in
            if case .compact(_, let trailing) = HUDKind.battery(alert).style { return trailing }
            return nil
        }
        XCTAssertEqual(Set(widths.compactMap { $0 }).count, 1)
    }

    func testBluetoothWingGrowsForABattery() {
        let device = BluetoothMonitor.Device(name: "Keyboard", address: "k", battery: nil)
        var charged = device
        charged.battery = 80
        guard case .compact(_, let without) = HUDKind.bluetooth(.connected(device)).style,
              case .compact(_, let with) = HUDKind.bluetooth(.connected(charged)).style
        else { return XCTFail() }
        XCTAssertGreaterThan(with!, without!)
    }

    func testCategoriesCoverSettings() {
        for kind in samples { XCTAssertTrue(HUDCategory.allCases.contains(kind.category)) }
        XCTAssertEqual(HUDKind.mute(true).category, .volume)
        XCTAssertEqual(HUDKind.peripheralBattery(.init(name: "m", address: "m", battery: 5)).category, .bluetooth)
    }

    func testContentIdentity() {
        XCTAssertEqual(IslandMode.hud(.unlocked).contentIdentity, .locked)
        XCTAssertEqual(IslandMode.hud(.volume).contentIdentity, .closed)
        XCTAssertEqual(IslandMode.hud(.nowPlaying).contentIdentity, .closed)
        let note = SystemNotification(appName: "a", title: "t", body: "b", bundleIdentifier: nil)
        XCTAssertEqual(IslandMode.hud(.notification(note)).contentIdentity, .hud(.notification(note)))
        XCTAssertEqual(IslandMode.expanded.contentIdentity, .expanded)
    }
}
