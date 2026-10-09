import AppKit

/// Application icons by bundle identifier, fetched once.
@MainActor
enum AppIcons {
    private static var cache: [String: NSImage?] = [:]

    static func icon(for bundleIdentifier: String?) -> NSImage? {
        guard let bundleIdentifier else { return nil }
        if let cached = cache[bundleIdentifier] { return cached }
        let icon = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
            .map { NSWorkspace.shared.icon(forFile: $0.path) }
        cache[bundleIdentifier] = icon
        return icon
    }

    private static let knownApps = [
        "messages": "com.apple.MobileSMS", "mail": "com.apple.mail", "calendar": "com.apple.iCal", "reminders": "com.apple.reminders",
        "notes": "com.apple.Notes", "facetime": "com.apple.FaceTime", "photos": "com.apple.Photos", "safari": "com.apple.Safari",
        "music": "com.apple.Music", "podcasts": "com.apple.podcasts", "tv": "com.apple.TV", "maps": "com.apple.Maps", "home": "com.apple.Home",
        "weather": "com.apple.weather", "app store": "com.apple.AppStore", "system settings": "com.apple.systempreferences",
        "find my": "com.apple.findmy", "news": "com.apple.news", "stocks": "com.apple.stocks", "freeform": "com.apple.freeform",
    ]

    /// The bundle behind an app's display name: a running app, a known Apple app, or an
    /// application folder entry of that name.
    static func bundle(named name: String) -> String? {
        if let running = NSWorkspace.shared.runningApplications.first(where: { $0.localizedName?.caseInsensitiveCompare(name) == .orderedSame }) {
            return running.bundleIdentifier
        }
        if let known = knownApps[name.lowercased()] { return known }
        let folders = ["/Applications", "/System/Applications", "/System/Applications/Utilities", NSHomeDirectory() + "/Applications"]
        for folder in folders {
            let url = URL(fileURLWithPath: folder).appendingPathComponent(name + ".app")
            if let bundle = Bundle(url: url)?.bundleIdentifier { return bundle }
        }
        return nil
    }

    static func name(for bundleIdentifier: String) -> String {
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) else { return bundleIdentifier }
        return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
    }
}
