import AppKit

/// Firefox hands macOS no artwork, so match the playing title against open tabs
/// and use the page's video thumbnail. The session file lags a few seconds.
@MainActor
final class FirefoxArtworkProvider: ArtworkProvider {
    private var cache = ArtworkCache()

    func supports(bundleIdentifier: String) -> Bool {
        FirefoxTabs.bundleIdentifiers.contains(bundleIdentifier)
    }

    func artwork(for track: NowPlayingTrack) async -> NSImage? {
        for attempt in 0..<4 {
            if attempt > 0 { try? await Task.sleep(for: .seconds(6)) }
            if Task.isCancelled { return nil }
            if let image = await lookup(title: track.title) { return image }
        }
        return nil
    }

    private func lookup(title: String) async -> NSImage? {
        let tabs = await Task.detached(priority: .utility) { FirefoxTabs.openTabs() }.value
        let match = tabs.first(where: { $0.title.localizedCaseInsensitiveContains(title) })
        if ProcessInfo.processInfo.environment["ISLAND_DEBUG"] != nil {
            let youtube = tabs.filter { $0.url.host?.contains("youtube") == true }.count
            FileHandle.standardError.write(Data("firefox tabs=\(tabs.count) youtube=\(youtube) matched=\(match != nil) thumb=\(match.flatMap(\.url).flatMap(YouTubeThumbnail.url) != nil) title=\(title.prefix(20))\n".utf8))
        }
        guard let tab = match, let thumbnail = YouTubeThumbnail.url(for: tab.url) else { return nil }
        if let cached = cache[thumbnail] { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: thumbnail), let image = NSImage(data: data) else {
            return nil
        }
        cache[thumbnail] = image
        return image
    }
}
