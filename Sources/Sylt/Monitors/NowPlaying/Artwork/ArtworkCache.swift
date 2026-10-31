import AppKit

@MainActor
final class ArtworkCache {
    private var images: [URL: NSImage] = [:]
    private var order: [URL] = []
    private let limit: Int
    private let download: (URL) async -> NSImage?

    init(limit: Int = 40, download: @escaping (URL) async -> NSImage? = ArtworkCache.fetch) {
        self.limit = limit
        self.download = download
    }

    func image(at url: URL) async -> NSImage? {
        if let cached = images[url] { return cached }
        guard let image = await download(url) else { return nil }
        if images[url] == nil { order.append(url) }
        images[url] = image
        while order.count > limit { images.removeValue(forKey: order.removeFirst()) }
        return image
    }

    private nonisolated static func fetch(_ url: URL) async -> NSImage? {
        guard let (data, _) = try? await URLSession.shared.data(from: url) else { return nil }
        return NSImage(data: data)
    }
}
