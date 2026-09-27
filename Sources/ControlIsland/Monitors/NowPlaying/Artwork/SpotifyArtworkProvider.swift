import AppKit

@MainActor
final class SpotifyArtworkProvider: ArtworkProvider {
    private var cache: [URL: NSImage] = [:]

    func supports(bundleIdentifier: String) -> Bool {
        bundleIdentifier == "com.spotify.client"
    }

    func artwork(for track: NowPlayingTrack) async -> NSImage? {
        let source = #"tell application id "com.spotify.client" to get artwork url of current track"#
        guard let urlString = await AppleScript.string(source), let url = URL(string: urlString) else { return nil }
        if let cached = cache[url] { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: url), let image = NSImage(data: data) else {
            return nil
        }
        cache[url] = image
        return image
    }
}
