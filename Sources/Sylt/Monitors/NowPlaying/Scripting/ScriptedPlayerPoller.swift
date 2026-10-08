import Foundation

@MainActor
final class ScriptedPlayerPoller {
    var onSnapshot: ((ScriptedPlayer, PlayerSnapshot?) -> Void)?

    private(set) var player: ScriptedPlayer?
    private var timer: Timer?
    private var inflight: Task<Void, Never>?
    private var pollAgain = false

    func start(_ player: ScriptedPlayer) {
        guard self.player != player else { return }
        stop()
        self.player = player
        poll()
        timer = .every(2) { [weak self] in self?.poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        inflight?.cancel()
        inflight = nil
        pollAgain = false
        player = nil
    }

    /// A poll asked for while one is running follows it, so a command's effect shows at once.
    func poll() {
        guard let player else { return }
        guard inflight == nil else { pollAgain = true; return }
        inflight = Task { [weak self] in
            let snapshot = await AppleScript.run(player.snapshotScript) { PlayerSnapshot(descriptor: $0) }
            guard let self, !Task.isCancelled else { return }
            inflight = nil
            onSnapshot?(player, snapshot)
            if pollAgain {
                pollAgain = false
                poll()
            }
        }
    }
}
