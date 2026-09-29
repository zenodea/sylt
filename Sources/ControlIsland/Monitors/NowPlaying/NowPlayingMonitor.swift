import AppKit
import Combine

@MainActor
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var track: NowPlayingTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var position = PlaybackPosition.idle
    let trackChanges = PassthroughSubject<Void, Never>()
    let playbackResumed = PassthroughSubject<Void, Never>()

    private let adapter = MediaRemoteAdapterProcess()
    private var artworkCache: (hash: UInt, image: NSImage)?
    private var appIcons: [String: NSImage] = [:]
    private let artworkResolver = ArtworkResolver()
    private let scripted = ScriptedPlayerPoller()

    var available: Bool { MediaRemoteAdapterProcess.libraryURL != nil }

    func start() {
        scripted.onSnapshot = { [weak self] player, snapshot in self?.apply(snapshot, from: player) }
        adapter.start { [weak self] payload in
            Task { @MainActor in self?.apply(payload) }
        }
    }

    func stop() {
        artworkResolver.cancel()
        scripted.stop()
        adapter.stop()
        track = nil
        isPlaying = false
        position = .idle
    }

    func togglePlayPause() { perform(.playPause, key: .playPause) }
    func next() { perform(.next, key: .next) }
    func previous() { perform(.previous, key: .previous) }

    func seek(to seconds: TimeInterval) {
        guard let player = scripted.player else { return }
        Task { _ = await AppleScript.string(player.script(for: .seek(seconds))); scripted.poll() }
    }

    private func perform(_ command: ScriptedPlayer.Command, key: MediaKeySimulator.Key) {
        if let player = scripted.player {
            Task { _ = await AppleScript.string(player.script(for: command)); scripted.poll() }
        } else {
            MediaKeySimulator.press(key)
            adapter.send("refresh")
        }
    }

    private func apply(_ payload: NowPlayingPayload) {
        if ProcessInfo.processInfo.environment["ISLAND_DEBUG"] != nil {
            FileHandle.standardError.write(Data("payload bundle=\(payload.bundle ?? "-") title=\(payload.title?.prefix(20) ?? "-") playing=\(payload.playing) hash=\(payload.artworkHash)\n".utf8))
        }
        if let player = payload.bundle.flatMap(ScriptedPlayer.init(rawValue:)) {
            adapter.setRefreshInterval(20)
            scripted.start(player)
            scripted.poll()
            return
        }
        adapter.setRefreshInterval(3)
        scripted.stop()
        if payload.playing, !isPlaying, track != nil { playbackResumed.send() }
        isPlaying = payload.playing
        position = PlaybackPosition(
            elapsed: payload.elapsed ?? 0,
            rate: payload.playing ? (payload.rate ?? 1) : 0,
            timestamp: payload.timestamp.map { Date(timeIntervalSince1970: $0) } ?? .now
        )

        guard let title = payload.title, !title.isEmpty else {
            if payload.bundle == nil || payload.bundle != track?.bundleIdentifier { clear() }
            return
        }
        let next = NowPlayingTrack(
            title: title,
            artist: payload.artist ?? "",
            album: payload.album ?? "",
            duration: payload.duration,
            bundleIdentifier: payload.bundle,
            artworkHash: payload.artworkHash,
            artwork: artwork(for: payload) ?? appIcon(for: payload.bundle)
        )
        let changedSong = track.map { !$0.isSameSong(next) } ?? false
        if next != track { track = next }
        if changedSong { trackChanges.send() }
        if payload.artworkHash == 0, changedSong || track?.hasResolvedArtwork != true {
            resolveArtwork(for: next)
        }
    }

    private func apply(_ snapshot: PlayerSnapshot?, from player: ScriptedPlayer) {
        guard let snapshot else { return clear() }
        if snapshot.isPlaying, !isPlaying, track != nil { playbackResumed.send() }
        isPlaying = snapshot.isPlaying
        position = PlaybackPosition(elapsed: snapshot.position, rate: snapshot.isPlaying ? 1 : 0, timestamp: .now)

        var next = NowPlayingTrack(snapshot: snapshot, player: player)
        if let current = track, current.isSameSong(next) {
            next.artwork = current.artwork
            next.hasResolvedArtwork = current.hasResolvedArtwork
            if next != current { track = next }
            return
        }
        let hadTrack = track != nil
        next.artwork = appIcon(for: player.rawValue)
        track = next
        if hadTrack { trackChanges.send() }
        resolveArtwork(for: next)
    }

    private func clear() {
        track = nil
        isPlaying = false
        position = .idle
    }

    private func resolveArtwork(for target: NowPlayingTrack) {
        artworkResolver.resolve(target) { [weak self] image in
            guard let self, var current = track, current.isSameSong(target) else { return }
            current.artwork = image
            current.hasResolvedArtwork = true
            track = current
        }
    }

    private func appIcon(for bundleIdentifier: String?) -> NSImage? {
        guard let bundleIdentifier else { return nil }
        if let cached = appIcons[bundleIdentifier] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return nil }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        appIcons[bundleIdentifier] = icon
        return icon
    }

    private func artwork(for payload: NowPlayingPayload) -> NSImage? {
        if let encoded = payload.artwork, let data = Data(base64Encoded: encoded), let image = NSImage(data: data) {
            artworkCache = (payload.artworkHash, image)
            return image
        }
        return artworkCache?.hash == payload.artworkHash ? artworkCache?.image : nil
    }
}
