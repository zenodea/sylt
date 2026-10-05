import AppKit

struct SystemNotification: Hashable, Identifiable {
    let id = UUID()
    let appName: String
    let title: String
    let body: String
    let bundleIdentifier: String?

    @MainActor var icon: NSImage? { AppIcons.icon(for: bundleIdentifier) }
}
