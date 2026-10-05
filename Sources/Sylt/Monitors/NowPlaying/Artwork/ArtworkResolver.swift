import AppKit

/// Fills in artwork that MediaRemote withholds, asking the source app directly.
@MainActor
final class ArtworkResolver {
    private let providers: [ArtworkProvider] = [
        SpotifyArtworkProvider(),
        MusicArtworkProvider(),
        FirefoxArtworkProvider(),
    ]
    private var inflight: Task<Void, Never>?

    func resolve(_ track: NowPlayingTrack, completion: @escaping (NSImage) -> Void) {
        cancel()
        guard let bundleIdentifier = track.bundleIdentifier,
              let provider = providers.first(where: { $0.supports(bundleIdentifier: bundleIdentifier) })
        else { return }
        inflight = Task {
            guard let image = await provider.artwork(for: track), !Task.isCancelled else { return }
            completion(image)
        }
    }

    func cancel() {
        inflight?.cancel()
        inflight = nil
    }
}
