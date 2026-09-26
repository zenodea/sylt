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
        guard let store = latestSessionStore(),
              let compressed = try? Data(contentsOf: store),
              let json = MozLz4.decompress(compressed),
              let session = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let windows = session["windows"] as? [[String: Any]]
        else { return [] }

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

    private static func latestSessionStore() -> URL? {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let roots = ["Firefox", "zen"].compactMap { support?.appendingPathComponent("\($0)/Profiles") }
        let stores = roots.flatMap { root -> [URL] in
            let profiles = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil)) ?? []
            return profiles.map { $0.appendingPathComponent("sessionstore-backups/recovery.jsonlz4") }
        }
        return stores
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .max { modificationDate($0) < modificationDate($1) }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }
}
