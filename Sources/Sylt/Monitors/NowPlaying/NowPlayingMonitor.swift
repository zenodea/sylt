import AppKit
import Combine
import QuartzCore

@MainActor
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var track: NowPlayingTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var position = PlaybackPosition.idle
    @Published private(set) var playerVolume: Double?
    private var playerVolumeSetAt: CFTimeInterval = 0
    let trackChanges = PassthroughSubject<Void, Never>()
    let playbackResumed = PassthroughSubject<Void, Never>()
    @Published private(set) var sources: [String] = []
    private var pinnedSource: ScriptedPlayer?
    private var lastPayload: NowPlayingPayload?
    private var seekedAt: CFTimeInterval = 0
    private static let seekGrace: CFTimeInterval = 2
    private static let volumeGrace: CFTimeInterval = 1.5

    private let adapter = MediaRemoteAdapterProcess()
    private var artworkCache: (hash: UInt, image: NSImage)?
    private let artworkResolver = ArtworkResolver()
    private let scripted = ScriptedPlayerPoller()

    func start() {
        scripted.onSnapshot = { [weak self] player, snapshot in self?.apply(snapshot, from: player) }
        adapter.start { [weak self] payload in
            Task { @MainActor in self?.apply(payload) }
        }
    }

    func stop() {
        artworkResolver.cancel()
        scripted.stop()
        adapter.shutDown()
        track = nil
        isPlaying = false
        position = .idle
    }

    func togglePlayPause() { perform(.playPause, remote: .togglePlayPause) }
    func next() { perform(.next, remote: .next) }
    func previous() { perform(.previous, remote: .previous) }

    func select(source bundleIdentifier: String?) {
        let player = bundleIdentifier.flatMap(ScriptedPlayer.init(rawValue:))
        pinnedSource = player
        if let player {
            scripted.start(player)
            scripted.poll()
        } else if let lastPayload {
            apply(lastPayload)
        }
    }

    func setPlayerVolume(_ level: Double) {
        guard let player = scripted.player else { return }
        let clamped = min(max(level, 0), 1)
        playerVolume = clamped
        playerVolumeSetAt = CACurrentMediaTime()
        Task { await AppleScript.string(player.script(for: .volume(clamped))) }
    }

    func seek(to seconds: TimeInterval) {
        position = PlaybackPosition(elapsed: seconds, rate: isPlaying ? 1 : 0, timestamp: .now)
        seekedAt = CACurrentMediaTime()
        if let player = scripted.player {
            Task { await AppleScript.string(player.script(for: .seek(seconds))); scripted.poll() }
        } else {
            MediaRemoteCommands.seek(to: seconds)
            adapter.requestRefresh()
        }
    }

    private func perform(_ command: ScriptedPlayer.Command, remote: MediaRemoteCommands.Command) {
        if let player = scripted.player {
            Task { await AppleScript.string(player.script(for: command)); scripted.poll() }
        } else {
            MediaRemoteCommands.send(remote)
            adapter.requestRefresh()
        }
    }

    private func apply(_ payload: NowPlayingPayload) {
        DebugLog.write("payload bundle=\(payload.bundle ?? "-") title=\(payload.title?.prefix(20) ?? "-") playing=\(payload.playing) hash=\(payload.artworkHash)")
        lastPayload = payload
        refreshSources()
        if scripted.player == nil || payload.bundle != scripted.player?.rawValue, playerVolume != nil, pinnedSource == nil { playerVolume = nil }
        if let pinned = pinnedSource, payload.bundle != pinned.rawValue { return }
        if let player = payload.bundle.flatMap(ScriptedPlayer.init(rawValue:)) {
            scripted.start(player)
            scripted.poll()
            return
        }
        scripted.stop()
        if payload.playing, !isPlaying, track != nil { playbackResumed.send() }
        isPlaying = payload.playing
        let reported = PlaybackPosition(
            elapsed: payload.elapsed ?? 0,
            rate: payload.playing ? (payload.rate ?? 1) : 0,
            timestamp: payload.timestamp.map { Date(timeIntervalSince1970: $0) } ?? .now
        )
        if !isStale(reported) { position = reported }

        guard let title = payload.title, !title.isEmpty else {
            if payload.bundle == nil || payload.bundle != track?.bundleIdentifier { clear() }
            return
        }
        var next = NowPlayingTrack(
            title: title,
            artist: payload.artist ?? "",
            album: payload.album ?? "",
            duration: payload.duration,
            bundleIdentifier: payload.bundle,
            artworkHash: payload.artworkHash,
            artwork: nil
        )
        let changedSong = track.map { !$0.isSameSong(next) } ?? false
        next.artwork = artwork(for: payload) ?? (changedSong ? nil : track?.artwork) ?? AppIcons.icon(for: payload.bundle)
        if next != track { track = next }
        if changedSong { trackChanges.send() }
        if payload.artworkHash == 0, changedSong || track?.hasResolvedArtwork != true {
            resolveArtwork(for: next)
        }
    }

    private func apply(_ snapshot: PlayerSnapshot?, from player: ScriptedPlayer) {
        refreshSources()
        guard let snapshot else {
            if pinnedSource == player { return select(source: nil) }
            return clear()
        }
        if snapshot.isPlaying, !isPlaying, track != nil { playbackResumed.send() }
        isPlaying = snapshot.isPlaying
        if CACurrentMediaTime() - playerVolumeSetAt > Self.volumeGrace, snapshot.volume != playerVolume { playerVolume = snapshot.volume }
        let reported = PlaybackPosition(elapsed: snapshot.position, rate: snapshot.isPlaying ? 1 : 0, timestamp: .now)
        if !isStale(reported) { position = reported }

        var next = NowPlayingTrack(snapshot: snapshot, player: player)
        if let current = track, current.isSameSong(next) {
            next.artwork = current.artwork
            next.hasResolvedArtwork = current.hasResolvedArtwork
            if next != current { track = next }
            return
        }
        let hadTrack = track != nil
        next.artwork = track?.artwork ?? AppIcons.icon(for: player.rawValue)
        track = next
        if hadTrack { trackChanges.send() }
        resolveArtwork(for: next)
    }

    private func isStale(_ reported: PlaybackPosition) -> Bool {
        guard CACurrentMediaTime() - seekedAt < Self.seekGrace else { return false }
        return abs(reported.elapsed(at: .now) - position.elapsed(at: .now)) > 1.5
    }

    private func clear() {
        track = nil
        isPlaying = false
        position = .idle
    }

    private func refreshSources() {
        var next: [String] = []
        if let bundle = lastPayload?.bundle, lastPayload?.title?.isEmpty == false { next.append(bundle) }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        for player in ScriptedPlayer.allCases where running.contains(player.rawValue) && !next.contains(player.rawValue) {
            next.append(player.rawValue)
        }
        if next != sources { sources = next }
    }

    private func resolveArtwork(for target: NowPlayingTrack) {
        artworkResolver.resolve(target) { [weak self] image in
            guard let self, var current = track, current.isSameSong(target) else { return }
            current.artwork = image
            current.hasResolvedArtwork = true
            track = current
        }
    }

    private func artwork(for payload: NowPlayingPayload) -> NSImage? {
        if let encoded = payload.artwork, let data = Data(base64Encoded: encoded), let image = NSImage(data: data) {
            artworkCache = (payload.artworkHash, image)
            return image
        }
        return artworkCache?.hash == payload.artworkHash ? artworkCache?.image : nil
    }
}
