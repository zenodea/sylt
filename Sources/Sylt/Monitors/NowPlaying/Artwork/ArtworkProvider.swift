import AppKit

@MainActor
protocol ArtworkProvider {
    func supports(bundleIdentifier: String) -> Bool
    func artwork(for track: NowPlayingTrack) async -> NSImage?
}
