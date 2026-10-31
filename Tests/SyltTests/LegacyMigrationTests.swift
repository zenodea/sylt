import XCTest
@testable import Sylt

final class LegacyMigrationTests: XCTestCase {
    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory.appendingPathComponent("sylt-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    private func write(_ text: String, to path: String) throws {
        let url = root.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    private func read(_ path: String) -> String? {
        try? String(contentsOf: root.appendingPathComponent(path), encoding: .utf8)
    }

    func testOldFilesWinAndNewOnesStay() throws {
        try write("old", to: "old/todos.json")
        try write("old", to: "old/PluginData/shelf/items.json")
        try write("", to: "old/.DS_Store")
        try write("new", to: "new/todos.json")
        try write("new", to: "new/PluginData/weather/cache.json")
        LegacyMigration.merge(root.appendingPathComponent("old"), into: root.appendingPathComponent("new"))
        XCTAssertEqual(read("new/todos.json"), "old")
        XCTAssertEqual(read("new/PluginData/shelf/items.json"), "old")
        XCTAssertEqual(read("new/PluginData/weather/cache.json"), "new")
        XCTAssertNil(read("new/.DS_Store"))
    }

    func testAMissingTargetTakesTheWholeFolder() throws {
        try write("old", to: "old/Plugins/mine/plugin.json")
        LegacyMigration.merge(root.appendingPathComponent("old"), into: root.appendingPathComponent("new"))
        XCTAssertEqual(read("new/Plugins/mine/plugin.json"), "old")
    }
}
