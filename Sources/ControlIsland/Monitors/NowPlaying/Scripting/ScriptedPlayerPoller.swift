import Foundation

@MainActor
final class ScriptedPlayerPoller {
    var onSnapshot: ((ScriptedPlayer, PlayerSnapshot?) -> Void)?

    private(set) var player: ScriptedPlayer?
    private var timer: Timer?
    private var inflight: Task<Void, Never>?

    func start(_ player: ScriptedPlayer) {
        guard self.player != player else { return }
        stop()
        self.player = player
        poll()
        timer = .scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        inflight?.cancel()
        inflight = nil
        player = nil
    }

    func poll() {
        guard let player, inflight == nil else { return }
        inflight = Task { [weak self] in
            let snapshot = await AppleScript.run(player.snapshotScript, PlayerSnapshot.init(descriptor:))
            guard let self, !Task.isCancelled else { return }
            inflight = nil
            onSnapshot?(player, snapshot)
        }
    }
}
