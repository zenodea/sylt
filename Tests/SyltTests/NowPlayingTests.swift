import AppKit
import Compression
import XCTest
@testable import Sylt

@MainActor
final class NowPlayingTests: XCTestCase {
    private final class GatedProvider: ArtworkProvider {
        var calls = 0
        private var waiting: [CheckedContinuation<Void, Never>] = []

        func supports(bundleIdentifier: String) -> Bool { true }

        func artwork(for track: NowPlayingTrack) async -> NSImage? {
            calls += 1
            await withCheckedContinuation { waiting.append($0) }
            return NSImage(size: NSSize(width: 1, height: 1))
        }

        func finishAll() {
            waiting.forEach { $0.resume() }
            waiting = []
        }
    }

    private func until(_ condition: () -> Bool) async {
        for _ in 0..<400 where !condition() { try? await Task.sleep(for: .milliseconds(5)) }
    }

    private func track(_ title: String) -> NowPlayingTrack {
        NowPlayingTrack(title: title, artist: "Artist", album: "", duration: nil, bundleIdentifier: "app", artworkHash: 0, artwork: nil)
    }

    func testRepeatedReportsOfASongShareOneLookup() async {
        let provider = GatedProvider()
        let resolver = ArtworkResolver(providers: [provider])
        var delivered: [String] = []
        resolver.resolve(track("A")) { _ in delivered.append("A") }
        resolver.resolve(track("A")) { _ in delivered.append("A again") }
        await until { provider.calls == 1 }
        provider.finishAll()
        await until { !delivered.isEmpty }
        XCTAssertEqual(provider.calls, 1)
        XCTAssertEqual(delivered, ["A"])

        resolver.resolve(track("B")) { _ in delivered.append("B") }
        resolver.resolve(track("C")) { _ in delivered.append("C") }
        await until { provider.calls == 3 }
        provider.finishAll()
        await until { delivered.count == 2 }
        await Task.yield()
        XCTAssertEqual(delivered, ["A", "C"], "the lookup for B was replaced and delivers nothing")
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

    func testArtworkCacheDownloadsOnceAndForgetsTheOldest() async {
        final class Log { var urls: [URL] = [] }
        let log = Log()
        let cache = ArtworkCache(limit: 2) { url in
            log.urls.append(url)
            return NSImage(size: NSSize(width: 1, height: 1))
        }
        let a = URL(string: "https://example.com/a")!, b = URL(string: "https://example.com/b")!, c = URL(string: "https://example.com/c")!
        for url in [a, a, b, c, b, a] { _ = await cache.image(at: url) }
        XCTAssertEqual(log.urls, [a, b, c, a], "a is fetched again only after c pushed it out")
    }

    func testMediaTitleMatchesItsTabDespiteDoubledSpaces() {
        let media = FirefoxArtworkProvider.collapsingSpaces("Daft Punk - Alive 2007  [Full Concert]")
        let tab = FirefoxArtworkProvider.collapsingSpaces("Daft Punk - Alive 2007 [Full Concert] - YouTube")
        XCTAssertTrue(tab.localizedCaseInsensitiveContains(media))
    }

    func testFirefoxSessionGivesEachTabsCurrentPage() {
        let session = """
        {"windows": [{"tabs": [
            {"index": 2, "entries": [{"url": "https://a.com", "title": "A"}, {"url": "https://www.youtube.com/watch?v=x", "title": "Song - YouTube"}]},
            {"entries": []},
            {"index": 9, "entries": [{"url": "https://b.com", "title": "B"}]}
        ]}]}
        """
        let tabs = FirefoxTabs.tabs(inSession: Data(session.utf8))
        XCTAssertEqual(tabs.map(\.title), ["Song - YouTube", "B"])
        XCTAssertEqual(tabs.first?.url.host, "www.youtube.com")
        XCTAssertTrue(FirefoxTabs.tabs(inSession: Data("{}".utf8)).isEmpty)
    }

    func testFirefoxProfilesAreRelativeUnlessMarked() {
        let ini = """
        [Profile1]
        Name=default
        IsRelative=1
        Path=Profiles/abc.default

        [Profile0]
        IsRelative=0
        Path=/Volumes/Work/firefox

        [Profile2]
        Path=Profiles/xyz.dev
        """
        let root = URL(fileURLWithPath: "/Users/me/Firefox")
        XCTAssertEqual(FirefoxTabs.profilePaths(inIni: ini, root: root).map(\.path), [
            "/Users/me/Firefox/Profiles/abc.default", "/Volumes/Work/firefox", "/Users/me/Firefox/Profiles/xyz.dev",
        ])
    }

    func testPlayerSnapshotReadsTheScriptsList() throws {
        let list = NSAppleEventDescriptor.list()
        for item: NSAppleEventDescriptor in [.init(string: "Song"), .init(string: "Band"), .init(string: "Album"),
                                             .init(double: 200), .init(double: 12.5), .init(string: "playing"), .init(int32: 64)] {
            list.insert(item, at: 0)
        }
        let snapshot = try XCTUnwrap(PlayerSnapshot(descriptor: list))
        XCTAssertEqual(snapshot.title, "Song")
        XCTAssertEqual(snapshot.duration, 200)
        XCTAssertEqual(snapshot.position, 12.5)
        XCTAssertTrue(snapshot.isPlaying)
        XCTAssertEqual(snapshot.volume, 0.64)
        XCTAssertNil(PlayerSnapshot(descriptor: .list()), "a stopped player returns an empty list")
    }

    func testTransportScripts() {
        XCTAssertEqual(ScriptedPlayer.spotify.script(for: .next), #"tell application id "com.spotify.client" to next track"#)
        XCTAssertEqual(ScriptedPlayer.music.script(for: .seek(42.5)), #"tell application id "com.apple.Music" to set player position to 42.5"#)
        XCTAssertEqual(ScriptedPlayer.music.script(for: .volume(0.456)), #"tell application id "com.apple.Music" to set sound volume to 46"#)
    }

    func testSameSongIgnoresAlbumAndArtwork() {
        var other = track("A")
        other.album = "Live"
        other.artworkHash = 7
        XCTAssertTrue(track("A").isSameSong(other))
        XCTAssertNotEqual(track("A"), other)
        XCTAssertFalse(track("A").isSameSong(track("B")))
    }
}
