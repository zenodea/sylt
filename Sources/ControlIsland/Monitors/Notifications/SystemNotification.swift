import AppKit

struct SystemNotification: Hashable, Identifiable {
    let id = UUID()
    let appName: String
    let title: String
    let body: String
    let bundleIdentifier: String?

    var icon: NSImage? {
        guard let bundleIdentifier,
              let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
        else { return nil }
        return NSWorkspace.shared.icon(forFile: url.path)
    }
}
