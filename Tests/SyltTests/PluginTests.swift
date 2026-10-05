import Combine
import XCTest
@testable import Sylt

@MainActor
final class PluginTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let suite = "SyltTests.plugins.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    private let manifestJSON = """
    {"protocol": 1, "id": "demo", "name": "Demo", "run": "demo.sh", "accepts": ["files"],
     "settings": [{"key": "units", "title": "Units", "type": "choice", "options": ["c", "f"], "default": "c"},
                  {"key": "loud", "title": "Loud", "type": "bool", "default": true}]}
    """

    func testManifestDecodes() throws {
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(manifestJSON.utf8))
        XCTAssertEqual(manifest.id, "demo")
        XCTAssertTrue(manifest.acceptsFiles)
        XCTAssertFalse(manifest.isOneShot)
        XCTAssertEqual(manifest.settings?.count, 2)
        XCTAssertEqual(manifest.settings?[0].default?.stringValue, "c")
        XCTAssertEqual(manifest.settings?[1].default?.boolValue, true)
    }

    func testMessagesDecode() throws {
        let wing = try JSONDecoder().decode(PluginMessage.self, from: Data(#"{"wing": {"side": "left", "items": [{"symbol": "timer", "text": "4:59", "ring": 0.4}]}}"#.utf8))
        XCTAssertEqual(wing.wing?.items?.first?.text, "4:59")
        XCTAssertEqual(wing.wing?.items?.first?.ring, 0.4)
        let hud = try JSONDecoder().decode(PluginMessage.self, from: Data(#"{"hud": {"symbol": "x", "text": "Hi", "side": "right", "duration": 1.5}}"#.utf8))
        XCTAssertEqual(hud.hud?.duration, 1.5)
        let section = try JSONDecoder().decode(PluginMessage.self, from: Data(#"{"section": {"title": "Shelf", "files": ["/tmp/a"], "actions": [{"id": "clear", "title": "Clear"}]}}"#.utf8))
        XCTAssertEqual(section.section?.files, ["/tmp/a"])
        XCTAssertEqual(section.section?.height, PluginSection.headerHeight + PluginSection.filesHeight)
    }

    func testItemWidthsFollowContent() {
        XCTAssertEqual(PluginItem().width, 0)
        let glyph = PluginItem(symbol: "sun.max.fill")
        let text = PluginItem(symbol: "sun.max.fill", text: "12°")
        XCTAssertEqual(glyph.width, PluginItem.glyph)
        XCTAssertGreaterThan(text.width, glyph.width)
        XCTAssertEqual(PluginItem.width(of: [glyph, glyph]), PluginItem.glyph * 2 + 8)
    }

    func testExternalHUDStyles() {
        let both = ExternalHUD(pluginID: "p", hud: PluginHUD(symbol: "x", text: "Hello"))
        guard case .compact(let leading, let trailing) = both.style else { return XCTFail() }
        XCTAssertNotNil(leading); XCTAssertNotNil(trailing)
        let right = ExternalHUD(pluginID: "p", hud: PluginHUD(text: "Hello", side: "right"))
        guard case .compact(let rl, _) = right.style else { return XCTFail() }
        XCTAssertNil(rl)
        XCTAssertEqual(HUDKind.external(both).category, .plugins)
        XCTAssertEqual(HUDKind.external(ExternalHUD(pluginID: "p", hud: PluginHUD(duration: 4))).duration, 4)
    }

    func testOverlaysCanBeQuietedPerPlugin() throws {
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(manifestJSON.utf8))
        let store = PluginStore(defaults: defaults())
        XCTAssertTrue(store.showsHUDs(manifest))
        store.setShowsHUDs(false, manifest)
        XCTAssertFalse(store.showsHUDs(manifest))
        let clipboard = try JSONDecoder().decode(PluginManifest.self, from: Data(#"{"protocol": 1, "id": "c", "name": "C", "run": "c.py", "accepts": ["clipboard"]}"#.utf8))
        XCTAssertTrue(clipboard.wantsClipboard)
        XCTAssertFalse(clipboard.acceptsFiles)
        let hud = ExternalHUD(pluginID: "a", hud: PluginHUD(symbol: "x", text: "Done", side: "left", trailingSymbol: "checkmark.circle.fill"))
        let plain = ExternalHUD(pluginID: "a", hud: PluginHUD(symbol: "x", text: "Done", side: "left"))
        XCTAssertGreaterThan(hud.content, plain.content, "a trailing symbol reserves its room")
    }

    func testStoreDefaultsAndOverrides() throws {
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(manifestJSON.utf8))
        let store = PluginStore(defaults: defaults())
        XCTAssertTrue(store.isEnabled(manifest))
        store.setEnabled(false, manifest)
        XCTAssertFalse(store.isEnabled(manifest))
        XCTAssertEqual(store.values(for: manifest)["units"]?.stringValue, "c")
        store.set(.string("f"), for: "units", in: manifest)
        XCTAssertEqual(store.values(for: manifest)["units"]?.stringValue, "f")
        XCTAssertEqual(store.values(for: manifest)["loud"]?.boolValue, true)
    }

    func testPluginRoundTripThroughAProcess() throws {
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("island-plugin-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try """
        {"protocol": 1, "id": "echo", "name": "Echo", "run": "echo.sh"}
        """.write(to: folder.appendingPathComponent("plugin.json"), atomically: true, encoding: .utf8)
        try """
        #!/bin/sh
        read start
        echo '{"wing": {"side": "right", "items": [{"text": "hi"}]}}'
        case "$start" in *'"event":"start"'*) echo '{"hud": {"text": "started"}}';; esac
        read next
        case "$next" in *click*) echo '{"section": {"title": "Echo", "rows": [{"id": "r", "title": "clicked"}]}}';; esac
        """.write(to: folder.appendingPathComponent("echo.sh"), atomically: true, encoding: .utf8)
        let manifest = try JSONDecoder().decode(PluginManifest.self, from: Data(contentsOf: folder.appendingPathComponent("plugin.json")))
        let plugin = ExternalPlugin(manifest: manifest, folder: folder, isBundled: false, store: PluginStore(defaults: defaults()))

        let gotHUD = expectation(description: "hud")
        var hudText = ""
        let cancellable = plugin.huds.sink { hudText = $0.text ?? ""; gotHUD.fulfill() }
        plugin.start()
        wait(for: [gotHUD], timeout: 5)
        XCTAssertEqual(plugin.right.first?.text, "hi")
        XCTAssertEqual(hudText, "started")

        plugin.send(PluginEvent(event: "click", row: "r"))
        let gotSection = expectation(description: "section")
        let watcher = plugin.$section.compactMap { $0 }.first().sink { _ in gotSection.fulfill() }
        wait(for: [gotSection], timeout: 5)
        XCTAssertEqual(plugin.section?.title, "Echo")
        XCTAssertEqual(plugin.section?.rows?.first?.title, "clicked")
        plugin.stop()
        XCTAssertTrue(plugin.right.isEmpty)
        cancellable.cancel(); watcher.cancel()
        try? FileManager.default.removeItem(at: folder)
    }
}
