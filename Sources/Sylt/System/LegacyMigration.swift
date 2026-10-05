import Foundation

/// The app used to be called Control Island. Its settings and plugin folder are carried
/// over once, so the rename costs the user nothing.
enum LegacyMigration {
    private static let oldBundleIdentifier = "dev.zenodea.controlisland"
    private static let oldFolder = "Control Island"
    private static let marker = "migratedFromControlIsland"

    static func run() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: marker) else { return }
        defaults.set(true, forKey: marker)
        migrateDefaults(into: defaults)
        migrateSupportFolder()
    }

    private static func migrateDefaults(into defaults: UserDefaults) {
        guard let old = UserDefaults(suiteName: oldBundleIdentifier)?.persistentDomain(forName: oldBundleIdentifier) else { return }
        for (key, value) in old { defaults.set(value, forKey: key) }
    }

    /// Moves the old folder over, file by file, with the old contents winning: anything
    /// the new app wrote before this ran is minutes old.
    private static func migrateSupportFolder() {
        let files = FileManager.default
        guard let support = files.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let old = support.appendingPathComponent(oldFolder, isDirectory: true)
        let new = support.appendingPathComponent("Sylt", isDirectory: true)
        guard files.fileExists(atPath: old.path) else { return }
        merge(old, into: new)
        try? files.removeItem(at: old)
    }

    private static func merge(_ source: URL, into target: URL) {
        let files = FileManager.default
        var isDirectory: ObjCBool = false
        guard files.fileExists(atPath: target.path, isDirectory: &isDirectory), isDirectory.boolValue else {
            try? files.removeItem(at: target)
            try? files.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? files.moveItem(at: source, to: target)
            return
        }
        for child in (try? files.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)) ?? [] where child.lastPathComponent != ".DS_Store" {
            merge(child, into: target.appendingPathComponent(child.lastPathComponent))
        }
    }
}
