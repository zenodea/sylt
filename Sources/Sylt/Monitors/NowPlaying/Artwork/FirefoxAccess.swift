import AppKit
import Combine

/// Whether macOS lets the app read Firefox's profile folder. Recent releases protect
/// other apps' data until the user allows it, and refuse quietly with EPERM.
@MainActor
final class FirefoxAccess: ObservableObject {
    static let shared = FirefoxAccess()

    @Published private(set) var isDenied = false

    nonisolated static func report(_ error: Error) {
        let code = (error as NSError).code
        update(denied: code == NSFileReadNoPermissionError || code == Int(EPERM))
    }

    nonisolated static func reportSuccess() {
        update(denied: false)
    }

    static func openPrivacySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    private nonisolated static func update(denied: Bool) {
        Task { @MainActor in if shared.isDenied != denied { shared.isDenied = denied } }
    }
}
