import AppKit
import Combine

/// Whether macOS lets the app read Firefox's profile folder. Recent releases protect
/// other apps' data until the user allows it, and refuse quietly with EPERM.
@MainActor
final class FirefoxAccess: ObservableObject {
    static let shared = FirefoxAccess()

    @Published private(set) var isDenied = false

    nonisolated func report(_ error: Error) {
        let code = (error as NSError).code
        let denied = code == NSFileReadNoPermissionError || code == Int(EPERM)
        Task { @MainActor in if self.isDenied != denied { self.isDenied = denied } }
    }

    nonisolated func reportSuccess() {
        Task { @MainActor in if self.isDenied { self.isDenied = false } }
    }

    static func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
