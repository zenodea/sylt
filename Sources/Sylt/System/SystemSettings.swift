import AppKit

enum SystemSettings {
    enum Pane: String {
        case accessibility = "Privacy_Accessibility"
        case fullDiskAccess = "Privacy_AllFiles"
    }

    static func open(_ pane: Pane) {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane.rawValue)")!)
    }
}
