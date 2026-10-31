import AppKit

@MainActor
final class FirefoxArtworkProvider: ArtworkProvider {
    private let cache = ArtworkCache()

    func supports(bundleIdentifier: String) -> Bool {
        FirefoxTabs.bundleIdentifiers.contains(bundleIdentifier)
    }

    func artwork(for track: NowPlayingTrack) async -> NSImage? {
        // The session file lags the playing tab by a few seconds.
        for attempt in 0..<4 {
            if attempt > 0 { try? await Task.sleep(for: .seconds(6)) }
            if Task.isCancelled { return nil }
            if let image = await lookup(title: track.title) { return image }
        }
        return nil
    }

    private func lookup(title: String) async -> NSImage? {
        let tabs = await Task.detached(priority: .utility) { FirefoxTabs.openTabs() }.value
        let wanted = Self.collapsingSpaces(title)
        let thumbnail = tabs.first { Self.collapsingSpaces($0.title).localizedCaseInsensitiveContains(wanted) }.flatMap { YouTubeThumbnail.url(for: $0.url) }
        DebugLog.write("firefox: \(tabs.count) tabs, thumbnail=\(thumbnail?.absoluteString ?? "none") for \(title.debugDescription)")
        guard let thumbnail else { return nil }
        return await cache.image(at: thumbnail)
    }

    // Tab titles collapse runs of spaces the way HTML renders them; media titles keep them.
    static func collapsingSpaces(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
