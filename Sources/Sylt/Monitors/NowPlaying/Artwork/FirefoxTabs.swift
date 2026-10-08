import AppKit
import Foundation

struct BrowserTab {
    let title: String
    let url: URL
}

enum FirefoxTabs {
    static let bundleIdentifiers: Set<String> = [
        "org.mozilla.firefox", "org.mozilla.firefoxdeveloperedition", "org.mozilla.nightly", "app.zen-browser.zen",
    ]

    private static let applicationFolders = ["Firefox", "zen", "Floorp", "LibreWolf"]

    static func openTabs() -> [BrowserTab] {
        guard let store = latestSessionStore() else { log("no session store"); return [] }
        let compressed: Data
        do {
            compressed = try Data(contentsOf: store)
            FirefoxAccess.reportSuccess()
        } catch {
            FirefoxAccess.report(error)
            log("unreadable (\((error as NSError).code)): \(store.path)")
            return []
        }
        guard let json = MozLz4.decompress(compressed) else { log("decompress failed, \(compressed.count) bytes"); return [] }
        guard let session = try? JSONSerialization.jsonObject(with: json) as? [String: Any],
              let windows = session["windows"] as? [[String: Any]]
        else { log("no windows in session"); return [] }

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
            do { directories += try FileManager.default.contentsOfDirectory(at: profiles, includingPropertiesForKeys: nil) } catch {
                if FileManager.default.fileExists(atPath: root.path) { FirefoxAccess.report(error) }
            }
            return directories
        }
    }

    /// The profile a running Firefox has locked, found through its open files.
    private static func lockedProfileDirectories() -> [URL] {
        NSWorkspace.shared.runningApplications
            .filter { $0.bundleIdentifier.map(bundleIdentifiers.contains) == true }
            .flatMap { ProcessFiles.openPaths(pid: $0.processIdentifier) }
            .filter { $0.hasSuffix("/.parentlock") || $0.hasSuffix("/lock") || $0.hasSuffix("/places.sqlite") }
            .map { URL(fileURLWithPath: $0).deletingLastPathComponent() }
    }

    private static func latestSessionStore() -> URL? {
        (lockedProfileDirectories() + profileDirectories())
            .map { $0.appendingPathComponent("sessionstore-backups/recovery.jsonlz4") }
            .filter { FileManager.default.fileExists(atPath: $0.path) }
            .max { modificationDate($0) < modificationDate($1) }
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    private static func log(_ text: String) {
        guard ProcessInfo.processInfo.environment["ISLAND_DEBUG"] != nil else { return }
        FileHandle.standardError.write(Data("firefox store: \(text)\n".utf8))
    }
}
