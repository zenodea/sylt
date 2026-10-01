import Combine
import XCTest
@testable import ControlIsland

@MainActor
final class HerdrMonitorTests: XCTestCase {
    private func agent(_ id: String, working: Bool) -> HerdrAgent {
        HerdrAgent(agent: "claude", agent_status: working ? "working" : "idle", pane_id: id, cwd: "/tmp/\(id)", focused: false, terminal_title_stripped: id)
    }

    func testWaitingAgentsComeFirst() {
        let monitor = HerdrMonitor()
        monitor.apply([agent("a", working: true), agent("b", working: false), agent("c", working: true)])
        XCTAssertEqual(monitor.agents.map(\.id), ["b", "a", "c"])
        XCTAssertEqual(monitor.workingCount, 2)
        XCTAssertEqual(monitor.waitingCount, 1)
    }

    func testFinishingAgentIsReportedOnce() {
        let monitor = HerdrMonitor()
        var finished: [String] = []
        let cancellable = monitor.finishedAgents.sink { finished.append($0.id) }
        monitor.apply([agent("a", working: true)])
        monitor.apply([agent("a", working: false)])
        monitor.apply([agent("a", working: false)])
        XCTAssertEqual(finished, ["a"])
        XCTAssertNotNil(monitor.statusSince["a"])
        cancellable.cancel()
    }

    func testStatusSinceForgetsDepartedAgents() {
        let monitor = HerdrMonitor()
        monitor.apply([agent("a", working: true), agent("b", working: true)])
        monitor.apply([agent("a", working: true)])
        XCTAssertEqual(Set(monitor.statusSince.keys), ["a"])
    }
}
