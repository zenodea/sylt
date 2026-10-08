import AppKit
import SwiftUI

struct NowPlayingTrack: Equatable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval?
    var bundleIdentifier: String?
    var artworkHash: UInt
    var artwork: NSImage? { didSet { accents = artwork?.sliceAccents(count: AudioBars.barCount) ?? [] } }
    private(set) var accents: [NSColor] = []
    var hasResolvedArtwork = false

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.album == rhs.album
            && lhs.duration == rhs.duration && lhs.bundleIdentifier == rhs.bundleIdentifier
            && lhs.artworkHash == rhs.artworkHash && lhs.hasResolvedArtwork == rhs.hasResolvedArtwork
    }

    init(title: String, artist: String, album: String, duration: TimeInterval?, bundleIdentifier: String?,
         artworkHash: UInt, artwork: NSImage?) {
        self.title = title
        self.artist = artist
        self.album = album
        self.duration = duration
        self.bundleIdentifier = bundleIdentifier
        self.artworkHash = artworkHash
        self.artwork = artwork
        accents = artwork?.sliceAccents(count: AudioBars.barCount) ?? []
    }

    init(snapshot: PlayerSnapshot, player: ScriptedPlayer) {
        self.init(title: snapshot.title, artist: snapshot.artist, album: snapshot.album, duration: snapshot.duration,
                  bundleIdentifier: player.rawValue, artworkHash: 0, artwork: nil)
    }

    var barColors: [Color] {
        accents.isEmpty ? [.white] : accents.map(Color.init)
    }

    var tint: Color {
        guard let accent = accents.isEmpty ? nil : accents[accents.count / 2] else { return .white }
        return Color(accent)
    }

    func isSameSong(_ other: NowPlayingTrack) -> Bool {
        other.title == title && other.artist == artist
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
