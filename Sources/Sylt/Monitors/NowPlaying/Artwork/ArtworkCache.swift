import AppKit

/// Images by key, forgetting the oldest once there are too many, so a long session
/// doesn't hold every cover it ever saw.
struct ArtworkCache {
    private var images: [URL: NSImage] = [:]
    private var order: [URL] = []
    private let limit: Int

    init(limit: Int = 40) { self.limit = limit }

    subscript(key: URL) -> NSImage? {
        get { images[key] }
        set {
            if images[key] == nil, newValue != nil { order.append(key) }
            images[key] = newValue
            while order.count > limit { images.removeValue(forKey: order.removeFirst()) }
        }
    }
}
