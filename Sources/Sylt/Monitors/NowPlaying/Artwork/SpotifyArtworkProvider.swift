import AppKit

@MainActor
final class SpotifyArtworkProvider: ArtworkProvider {
    private let cache = ArtworkCache()

    func supports(bundleIdentifier: String) -> Bool {
        bundleIdentifier == ScriptedPlayer.spotify.rawValue
    }

    func artwork(for track: NowPlayingTrack) async -> NSImage? {
        let source = #"tell application id "com.spotify.client" to get artwork url of current track"#
        guard let urlString = await AppleScript.string(source), let url = URL(string: urlString) else { return nil }
        return await cache.image(at: url)
    }
}
