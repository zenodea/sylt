import AppKit

@MainActor
final class MusicArtworkProvider: ArtworkProvider {
    func supports(bundleIdentifier: String) -> Bool {
        bundleIdentifier == "com.apple.Music"
    }

    func artwork(for track: NowPlayingTrack) async -> NSImage? {
        let source = #"tell application id "com.apple.Music" to get raw data of artwork 1 of current track"#
        guard let data = await AppleScript.data(source) else { return nil }
        return NSImage(data: data)
    }
}
