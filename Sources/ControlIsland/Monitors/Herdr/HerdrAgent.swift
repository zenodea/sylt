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
        if let title = terminal_title_stripped, !title.isEmpty { return title }
        return URL(fileURLWithPath: cwd).lastPathComponent
    }

    var isWorking: Bool { agent_status == "working" }
    var harness: Harness { Harness(rawValue: agent.lowercased()) ?? .other }
}

enum Harness: String {
    case claude
    case codex
    case pi
    case other

    var title: String {
        switch self {
        case .claude: "Claude"
        case .codex: "Codex"
        case .pi: "Pi"
        case .other: "Agent"
        }
    }

    var glyph: String {
        switch self {
        case .claude: "✳"
        case .codex: "◎"
        case .pi: "π"
        case .other: "●"
        }
    }

    var tint: (red: Double, green: Double, blue: Double) {
        switch self {
        case .claude: (0.85, 0.47, 0.34)
        case .codex: (0.62, 0.86, 0.72)
        case .pi: (0.55, 0.52, 0.95)
        case .other: (0.6, 0.6, 0.6)
        }
    }

    var applicationBundleIdentifiers: [String] {
        switch self {
        case .claude: ["com.anthropic.claudefordesktop"]
        case .codex: ["com.openai.codex", "com.openai.chat"]
        default: []
        }
    }
}
