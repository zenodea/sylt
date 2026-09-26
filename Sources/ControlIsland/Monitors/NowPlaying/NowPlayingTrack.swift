import AppKit

struct NowPlayingTrack: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval?
    var bundleIdentifier: String?
    var artworkHash: UInt
    var artwork: NSImage?
    var hasResolvedArtwork = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.album == rhs.album
            && lhs.duration == rhs.duration && lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.artworkHash == rhs.artworkHash && lhs.hasResolvedArtwork == rhs.hasResolvedArtwork
    }

    var isSameSong: (NowPlayingTrack) -> Bool {
        { $0.title == title && $0.artist == artist }
    }
}

struct PlaybackPosition: Equatable {
    var elapsed: TimeInterval
    var rate: Double
    var timestamp: Date

    static let idle = PlaybackPosition(elapsed: 0, rate: 0, timestamp: .distantPast)

    func elapsed(at now: Date) -> TimeInterval {
        elapsed + max(0, now.timeIntervalSince(timestamp)) * rate
    }
}
