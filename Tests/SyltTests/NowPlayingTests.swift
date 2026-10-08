import AppKit
import Compression
import XCTest
@testable import Sylt

@MainActor
final class NowPlayingTests: XCTestCase {
    private final class CountingProvider: ArtworkProvider {
        var calls = 0
        func supports(bundleIdentifier: String) -> Bool { true }
        func artwork(for track: NowPlayingTrack) async -> NSImage? {
            calls += 1
            try? await Task.sleep(for: .milliseconds(50))
            return NSImage(size: NSSize(width: 1, height: 1))
        }
    }

    private func track(_ title: String) -> NowPlayingTrack {
        NowPlayingTrack(title: title, artist: "Artist", album: "", duration: nil, bundleIdentifier: "app", artworkHash: 0, artwork: nil)
    }

    func testRepeatedReportsOfASongShareOneLookup() async {
        let provider = CountingProvider()
        let resolver = ArtworkResolver(providers: [provider])
        var delivered = 0
        resolver.resolve(track("A")) { _ in delivered += 1 }
        resolver.resolve(track("A")) { _ in delivered += 1 }
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(provider.calls, 1)
        XCTAssertEqual(delivered, 1)

        resolver.resolve(track("B")) { _ in delivered += 1 }
        resolver.resolve(track("C")) { _ in delivered += 1 }
        try? await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(provider.calls, 3)
        XCTAssertEqual(delivered, 2, "the cancelled lookup for B delivers nothing")
    }

    func testYouTubeThumbnails() {
        let expected = URL(string: "https://i.ytimg.com/vi/abc123/mqdefault.jpg")
        for page in ["https://www.youtube.com/watch?v=abc123&t=4s", "https://youtu.be/abc123", "https://m.youtube.com/shorts/abc123", "https://www.youtube.com/embed/abc123"] {
            XCTAssertEqual(YouTubeThumbnail.url(for: URL(string: page)!), expected, page)
        }
        XCTAssertNil(YouTubeThumbnail.url(for: URL(string: "https://www.youtube.com/feed/subscriptions")!))
        XCTAssertNil(YouTubeThumbnail.url(for: URL(string: "https://example.com/watch?v=abc123")!))
    }

    func testMozLz4RoundTrip() {
        let original = Data(String(repeating: "{\"windows\": [{\"tabs\": []}]} ", count: 40).utf8)
        var compressed = Data(count: original.count + 64)
        let written = compressed.withUnsafeMutableBytes { destination in
            original.withUnsafeBytes { source in
                compression_encode_buffer(
                    destination.baseAddress!.assumingMemoryBound(to: UInt8.self), destination.count,
                    source.baseAddress!.assumingMemoryBound(to: UInt8.self), source.count, nil, COMPRESSION_LZ4_RAW)
            }
        }
        var file = Data("mozLz40\0".utf8)
        file += withUnsafeBytes(of: UInt32(original.count).littleEndian) { Data($0) }
        file += compressed.prefix(written)
        XCTAssertEqual(MozLz4.decompress(file), original)
        XCTAssertNil(MozLz4.decompress(original), "a plain file has no magic")
    }

    func testPlaybackPositionAdvancesOnlyWhilePlaying() {
        let start = Date()
        let playing = PlaybackPosition(elapsed: 10, rate: 1, timestamp: start)
        let paused = PlaybackPosition(elapsed: 10, rate: 0, timestamp: start)
        XCTAssertEqual(playing.elapsed(at: start.addingTimeInterval(5)), 15)
        XCTAssertEqual(paused.elapsed(at: start.addingTimeInterval(5)), 10)
        XCTAssertEqual(playing.elapsed(at: start.addingTimeInterval(-5)), 10, "a report from the future never rewinds")
    }
}
