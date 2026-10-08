import AppKit

/// Fills in artwork that MediaRemote withholds, asking the source app directly.
@MainActor
final class ArtworkResolver {
    private let providers: [ArtworkProvider]
    private var inflight: (track: NowPlayingTrack, task: Task<Void, Never>)?

    init(providers: [ArtworkProvider]) {
        self.providers = providers
    }

    convenience init() {
        self.init(providers: [SpotifyArtworkProvider(), MusicArtworkProvider(), FirefoxArtworkProvider()])
    }

    /// Asks once per song; repeated reports of the same song leave the lookup running.
    func resolve(_ track: NowPlayingTrack, completion: @escaping (NSImage) -> Void) {
        if let inflight, inflight.track.isSameSong(track) { return }
        cancel()
        guard let bundleIdentifier = track.bundleIdentifier,
              let provider = providers.first(where: { $0.supports(bundleIdentifier: bundleIdentifier) })
        else { return }
        let task = Task { [weak self] in
            let image = await provider.artwork(for: track)
            guard !Task.isCancelled else { return }
            self?.inflight = nil
            if let image { completion(image) }
        }
        inflight = (track, task)
    }

    func cancel() {
        inflight?.task.cancel()
        inflight = nil
    }
}
