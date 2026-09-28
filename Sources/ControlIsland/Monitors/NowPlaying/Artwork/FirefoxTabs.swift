import Foundation

struct BrowserTab {
    let title: String
    let url: URL
}

enum FirefoxTabs {
    static let bundleIdentifiers: Set<String> = [
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly", "app.zen-browser.zen",
    ]

    static func openTabs() -> [BrowserTab] {
        let debug = ProcessInfo.processInfo.environment["ISLAND_DEBUG"] != nil
        func log(_ text: String) { if debug { FileHandle.standardError.write(Data("firefox store: \(text)\n".utf8)) } }
        guard let store = latestSessionStore() else { log("no store found; roots=\(profileRoots().map { FileManager.default.fileExists(atPath: $0.path) })"); return [] }
        guard let compressed = try? Data(contentsOf: store) else { log("unreadable"); return [] }
        guard let json = MozLz4.decompress(compressed) else { log("decompress failed, \(compressed.count) bytes, magic=\(compressed.prefix(8).map { String(format: "%02x", $0) }.joined())"); return [] }
        guard let session = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { log("json failed"); return [] }
        guard let windows = session["windows"] as? [[String: Any]] else { log("no windows key: \(session.keys.sorted())"); return [] }
        log("windows=\(windows.count)")

        return windows.flatMap { window -> [BrowserTab] in
            let tabs = window["tabs"] as? [[String: Any]] ?? []
            return tabs.compactMap { tab in
                guard let entries = tab["entries"] as? [[String: Any]], !entries.isEmpty else { return nil }
                let index = (tab["index"] as? Int ?? entries.count) - 1
                let entry = entries[min(max(index, 0), entries.count - 1)]
                guard let url = (entry["url"] as? String).flatMap(URL.init(string:)) else { return nil }
                return BrowserTab(title: entry["title"] as? String ?? "", url: url)
            }
        }
    }

    private static let applicationFolders = ["Firefox", "zen", "Floorp", "LibreWolf"]

    private static func profileRoots() -> [URL] {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        return applicationFolders.compactMap { support?.appendingPathComponent($0) }
    }

    /// Profile directories from each profiles.ini, plus anything under Profiles/.
    private static func profileDirectories() -> [URL] {
        profileRoots().flatMap { root -> [URL] in
            var directories: [URL] = []
            if let ini = try? String(contentsOf: root.appendingPathComponent("profiles.ini"), encoding: .utf8) {
                var relative = true
                for line in ini.split(separator: "\n") {
                    if line.hasPrefix("[") { relative = true }
                    if line == "IsRelative=0" { relative = false }
                    if line.hasPrefix("Path=") {
                        let path = String(line.dropFirst(5))
                        directories.append(relative ? root.appendingPathComponent(path) : URL(fileURLWithPath: path))
                    }
                }
            }
            let profiles = root.appendingPathComponent("Profiles")
            directories += (try? FileManager.default.contentsOfDirectory(at: profiles, includingPropertiesForKeys: nil)) ?? []
            return directories
        }
    }

    private static func latestSessionStore() -> URL? {
        let stores = profileDirectories()
            .map { $0.appendingPathComponent("sessionstore-backups/recovery.jsonlz4") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        if ProcessInfo.processInfo.environment["ISLAND_DEBUG"] != nil {
            let dirs = profileDirectories()
            let backups = dirs.map { FileManager.default.fileExists(atPath: $0.appendingPathComponent("sessionstore-backups").path) }
            FileHandle.standardError.write(Data("firefox profiles=\(dirs.count) withBackups=\(backups) stores=\(stores.count)\n".utf8))
        }
        return stores.max { modificationDate($0) < modificationDate($1) }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
