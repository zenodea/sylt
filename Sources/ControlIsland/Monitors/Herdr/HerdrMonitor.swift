import Foundation
import Combine

@MainActor
final class HerdrMonitor: ObservableObject {
    @Published private(set) var agents: [HerdrAgent] = []
    @Published private(set) var available = false
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
                    self.update(decoded.result.agents)
                } else {
                    self.available = false
                }
            }
        }
    }

    private func update(_ next: [HerdrAgent]) {
        guard next != agents else { return }
        let wasWorking = Set(agents.filter(\.isWorking).map(\.id))
        agents = next
        for agent in next where !agent.isWorking && wasWorking.contains(agent.id) {
            finishedAgents.send(agent)
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
