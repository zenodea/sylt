import Foundation
import Combine

struct HerdrAgent: Identifiable, Equatable, Decodable {
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

@MainActor
final class HerdrMonitor: ObservableObject {
    @Published private(set) var agents: [HerdrAgent] = []
    @Published private(set) var available = false

    private var timer: Timer?
    private let binary: String? = {
        let candidates = [
            "\(NSHomeDirectory())/.local/bin/herdr",
            "/opt/homebrew/bin/herdr",
            "/usr/local/bin/herdr",
        ]
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }
    }()

    var workingCount: Int { agents.filter(\.isWorking).count }
    var idleCount: Int { agents.count - workingCount }

    func start() {
        guard binary != nil else { return }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func focus(_ agent: HerdrAgent) {
        run(["agent", "focus", agent.pane_id]) { _ in }
    }

    private func poll() {
        run(["agent", "list"]) { [weak self] data in
            guard let data else { return }
            struct Envelope: Decodable {
                struct Result: Decodable { let agents: [HerdrAgent] }
                let result: Result
            }
            let decoded = try? JSONDecoder().decode(Envelope.self, from: data)
            Task { @MainActor in
                guard let self else { return }
                if let decoded {
                    self.available = true
                    if decoded.result.agents != self.agents { self.agents = decoded.result.agents }
                } else {
                    self.available = false
                }
            }
        }
    }

    private func run(_ args: [String], completion: @escaping (Data?) -> Void) {
        guard let binary else { return completion(nil) }
        DispatchQueue.global(qos: .utility).async {
            let p = Process()
            p.executableURL = URL(fileURLWithPath: binary)
            p.arguments = args
            let pipe = Pipe()
            p.standardOutput = pipe
            p.standardError = FileHandle.nullDevice
            do {
                try p.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                completion(p.terminationStatus == 0 ? data : nil)
            } catch {
                completion(nil)
            }
        }
    }
}
