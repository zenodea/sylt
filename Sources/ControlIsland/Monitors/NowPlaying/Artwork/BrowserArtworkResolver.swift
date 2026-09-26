import AppKit

/// Finds artwork for browser playback that MediaRemote reports without any,
/// by matching the playing title against open tabs and using the page's thumbnail.
@MainActor
final class BrowserArtworkResolver {
    private var cache: [URL: NSImage] = [:]
    private var inflight: Task<Void, Never>?

    func cancel() {
        inflight?.cancel()
        inflight = nil
    }

    func resolve(title: String, bundleIdentifier: String?, attempts: Int = 4, completion: @escaping (NSImage) -> Void) {
        cancel()
        guard let bundleIdentifier, FirefoxTabs.bundleIdentifiers.contains(bundleIdentifier) else { return }
        inflight = Task { [weak self] in
            for attempt in 0..<attempts {
                if attempt > 0 { try? await Task.sleep(for: .seconds(6)) }
                guard !Task.isCancelled, let self else { return }
                if let image = await self.lookup(title: title) {
                    guard !Task.isCancelled else { return }
                    completion(image)
                    return
                }
            }
        }
    }

    private func lookup(title: String) async -> NSImage? {
        let tabs = await Task.detached(priority: .utility) { FirefoxTabs.openTabs() }.value
        guard let tab = tabs.first(where: { $0.title.localizedCaseInsensitiveContains(title) }),
              let thumbnail = YouTubeThumbnail.url(for: tab.url)
        else { return nil }
        if let cached = cache[thumbnail] { return cached }
        guard let (data, _) = try? await URLSession.shared.data(from: thumbnail), let image = NSImage(data: data) else {
            return nil
        }
        cache[thumbnail] = image
        return image
    }
}
