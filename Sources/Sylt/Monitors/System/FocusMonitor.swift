import Combine
import Foundation

/// The active Focus mode, read from the Do Not Disturb assertion store.
@MainActor
final class FocusMonitor: ObservableObject {
    @Published var mode: String?
    let changes = PassthroughSubject<String?, Never>()

    private let directory = URL(fileURLWithPath: NSHomeDirectory() + "/Library/DoNotDisturb/DB")
    private var timer: Timer?
    private var primed = false

    func start() {
        guard timer == nil else { return }
        refresh()
        timer = .every(3) { [weak self] in self?.refresh() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        mode = nil
        primed = false
    }

    private func refresh() {
        let current = activeMode()
        defer { primed = true }
        guard current != mode else { return }
        mode = current
        if primed { changes.send(current) }
    }

    private func activeMode() -> String? {
        guard let assertions = json(directory.appendingPathComponent("Assertions.json")),
              let records = (assertions["data"] as? [[String: Any]])?.first?["storeAssertionRecords"] as? [[String: Any]],
              let details = records.first?["assertionDetails"] as? [String: Any],
              let identifier = details["assertionDetailsModeIdentifier"] as? String
        else { return nil }
        guard let configurations = json(directory.appendingPathComponent("ModeConfigurations.json")),
              let modes = (configurations["data"] as? [[String: Any]])?.first?["modeConfigurations"] as? [String: Any],
              let mode = (modes[identifier] as? [String: Any])?["mode"] as? [String: Any],
              let name = mode["name"] as? String
        else { return identifier.split(separator: ".").last.map(String.init) ?? "Focus" }
        return name
    }

    private func json(_ url: URL) -> [String: Any]? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
