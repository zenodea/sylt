import AppKit

MainActor.assumeIsolated {
    // The login item and macOS reopening apps from the last session can both start the
    // app at login; the second copy gives way.
    let others = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
    if !others.isEmpty { exit(0) }
    LegacyMigration.run()
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
