import AppKit
import Combine

@MainActor
final class HerdrMonitor: ObservableObject {
    @Published private(set) var agents: [HerdrAgent] = []
    @Published private(set) var available = false
    /// When each agent last changed between working and waiting, as seen by this app.
    @Published private(set) var statusSince: [String: Date] = [:]
    let finishedAgents = PassthroughSubject<HerdrAgent, Never>()

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
    var waitingCount: Int { agents.count - workingCount }

    /// Without the Herdr CLI, agent processes are found and watched directly.
    private let processes = ProcessAgents()

    func start() {
        guard timer == nil else { return }
        poll()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        agents = []
        available = false
    }

    /// Switches Herdr to the agent's pane and brings its terminal window to the front.
    func focus(_ agent: HerdrAgent) {
        guard binary != nil else { return processes.focus(agent) }
        let host = ProcessTree.hostApplication(ofProcessNamed: "herdr")
        if let host {
            NSApp.yieldActivation(to: host)
            host.activate()
        }
        run(["agent", "focus", agent.pane_id]) { _ in
            Task { @MainActor in
                guard let host else { return }
                WindowRaiser.raise(in: host, titleContaining: agent.terminal_title_stripped)
            }
        }
    }

    private func poll() {
        guard binary != nil else {
            let agents = processes.scan()
            available = !agents.isEmpty
            update(agents)
            return
        }
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
                    self.update(decoded.result.agents)
                } else {
                    self.available = false
                }
            }
        }
    }

    /// Waiting agents first: they are the ones that need you.
    private func update(_ next: [HerdrAgent]) {
        let sorted = next.sorted { ($0.isWorking ? 1 : 0, $0.id) < ($1.isWorking ? 1 : 0, $1.id) }
        guard sorted != agents else { return }
        let previous = Dictionary(agents.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let now = Date()
        for agent in sorted {
            guard let before = previous[agent.id] else { statusSince[agent.id] = now; continue }
            guard before.isWorking != agent.isWorking else { continue }
            statusSince[agent.id] = now
            if before.isWorking { finishedAgents.send(agent) }
        }
        statusSince = statusSince.filter { id, _ in sorted.contains { $0.id == id } }
        agents = sorted
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
