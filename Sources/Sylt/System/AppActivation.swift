import AppKit

enum AppActivation {
    /// Brings the app forward, launching it first when it isn't running.
    static func activate(bundle: String) {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first {
            activate(running)
        } else if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundle) {
            NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        }
    }

    static func activate(_ app: NSRunningApplication) {
        NSApp.yieldActivation(to: app)
        app.activate()
    }
}
