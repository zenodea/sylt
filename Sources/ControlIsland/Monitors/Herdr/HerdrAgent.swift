import Foundation

struct HerdrAgent: Identifiable, Hashable, Decodable {
    var id: String { pane_id }
    let agent: String
    let agent_status: String
    let pane_id: String
    let cwd: String
    let focused: Bool
    let terminal_title_stripped: String?

    var title: String {
        if let t = terminal_title_stripped, !t.isEmpty { return t }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }
    var isWorking: Bool { agent_status == "working" }
}
