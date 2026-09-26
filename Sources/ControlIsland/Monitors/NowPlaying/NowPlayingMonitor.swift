import AppKit
import Combine

@MainActor
final class NowPlayingMonitor: ObservableObject {
    @Published private(set) var track: NowPlayingTrack?
    @Published private(set) var isPlaying = false
    @Published private(set) var position = PlaybackPosition.idle
    let trackChanges = PassthroughSubject<Void, Never>()

    private let adapter = MediaRemoteAdapterProcess()
    private var artworkCache: (hash: UInt, image: NSImage)?

    var available: Bool { MediaRemoteAdapterProcess.libraryURL != nil }

    func start() {
        adapter.start { [weak self] payload in
            Task { @MainActor in self?.apply(payload) }
        }
    }

    func togglePlayPause() { adapter.send("toggle") }
    func next() { adapter.send("next") }
    func previous() { adapter.send("previous") }
    func seek(to seconds: TimeInterval) { adapter.send("seek \(seconds)") }

    private func apply(_ payload: NowPlayingPayload) {
        isPlaying = payload.playing
        position = PlaybackPosition(
            elapsed: payload.elapsed ?? 0,
            rate: payload.playing ? (payload.rate ?? 1) : 0,
            timestamp: payload.timestamp.map { Date(timeIntervalSince1970: $0) } ?? .now
        )

        guard let title = payload.title, !title.isEmpty else {
            track = nil
            return
        }
        let next = NowPlayingTrack(
            title: title,
            artist: payload.artist ?? "",
            album: payload.album ?? "",
            duration: payload.duration,
            bundleIdentifier: payload.bundle,
            artworkHash: payload.artworkHash,
            artwork: artwork(for: payload)
        )
        let changedSong = track.map { !$0.isSameSong(next) } ?? false
        if next != track { track = next }
        if changedSong { trackChanges.send() }
    }

    private func artwork(for payload: NowPlayingPayload) -> NSImage? {
        if let encoded = payload.artwork, let data = Data(base64Encoded: encoded), let image = NSImage(data: data) {
            artworkCache = (payload.artworkHash, image)
            return image
        }
        return artworkCache?.hash == payload.artworkHash ? artworkCache?.image : nil
    }
}
