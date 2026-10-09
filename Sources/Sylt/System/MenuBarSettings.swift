import AppKit

/// macOS's own menu bar settings, read and written where System Settings keeps them.
enum MenuBarSettings {
    /// When macOS hides the menu bar, as System Settings offers it.
    enum Hiding: String, CaseIterable, Identifiable {
        case always, desktop, fullscreen, never

        var id: String { rawValue }

        var title: String {
            switch self {
            case .always: "Always"
            case .desktop: "On the desktop only"
            case .fullscreen: "In full screen only"
            case .never: "Never"
            }
        }

        /// The two flags macOS stores: hide on the desktop, and show in full screen.
        init(hidesOnDesktop: Bool, visibleInFullscreen: Bool) {
            switch (hidesOnDesktop, visibleInFullscreen) {
            case (true, false): self = .always
            case (true, true): self = .desktop
            case (false, false): self = .fullscreen
            case (false, true): self = .never
            }
        }

        var hidesOnDesktop: Bool { self == .always || self == .desktop }
        var visibleInFullscreen: Bool { self == .desktop || self == .never }
    }

    /// One of the status items macOS draws itself.
    struct Item: Identifiable {
        let title: String
        let symbol: String
        let domain: String
        let key: String
        /// What macOS does when nothing is stored.
        let shownByDefault: Bool
        /// Stored as "hidden" rather than "shown".
        var inverted = false

        var id: String { key }
    }

    static let items: [Item] = [
        Item(title: "Wi-Fi", symbol: "wifi", domain: controlCenter, key: "NSStatusItem VisibleCC WiFi", shownByDefault: true),
        Item(title: "Bluetooth", symbol: "dot.radiowaves.right", domain: controlCenter, key: "NSStatusItem VisibleCC Bluetooth", shownByDefault: false),
        Item(title: "Sound", symbol: "speaker.wave.2.fill", domain: controlCenter, key: "NSStatusItem VisibleCC Sound", shownByDefault: false),
        Item(title: "Battery", symbol: "battery.75percent", domain: controlCenter, key: "NSStatusItem VisibleCC Battery", shownByDefault: true),
        Item(title: "Clock", symbol: "clock.fill", domain: controlCenter, key: "NSStatusItem VisibleCC Clock", shownByDefault: true),
        Item(title: "Now Playing", symbol: "play.circle.fill", domain: controlCenter, key: "NSStatusItem VisibleCC NowPlaying", shownByDefault: true),
        Item(title: "Display", symbol: "sun.max.fill", domain: controlCenter, key: "NSStatusItem VisibleCC Display", shownByDefault: false),
        Item(title: "Screen Mirroring", symbol: "airplayvideo", domain: controlCenter, key: "NSStatusItem VisibleCC ScreenMirroring", shownByDefault: false),
        Item(title: "Spotlight", symbol: "magnifyingglass", domain: "com.apple.Spotlight", key: "MenuItemHidden", shownByDefault: true, inverted: true),
        Item(title: "Siri", symbol: "waveform.circle.fill", domain: "com.apple.Siri", key: "StatusMenuVisible", shownByDefault: true),
    ]

    private static let controlCenter = "com.apple.controlcenter"
    private static let hideKey = "_HideMenuBar"
    private static let fullscreenKey = "AppleMenuBarVisibleInFullscreen"
    private static var restart: Timer?

    static var hiding: Hiding {
        Hiding(hidesOnDesktop: bool(hideKey, in: kCFPreferencesAnyApplication as String) ?? false,
               visibleInFullscreen: bool(fullscreenKey, in: kCFPreferencesAnyApplication as String) ?? false)
    }

    static func setHiding(_ hiding: Hiding) {
        set(hideKey, hiding.hidesOnDesktop, in: kCFPreferencesAnyApplication as String)
        set(fullscreenKey, hiding.visibleInFullscreen, in: kCFPreferencesAnyApplication as String)
        DistributedNotificationCenter.default().post(name: Notification.Name("AppleInterfaceMenuBarHidingChangedNotification"), object: nil)
    }

    static func isShown(_ item: Item) -> Bool {
        guard let stored = bool(item.key, in: item.domain) else { return item.shownByDefault }
        return stored != item.inverted
    }

    /// Control Center draws these items and reads its settings once, so it is restarted
    /// a moment after the last change.
    @MainActor static func setShown(_ item: Item, _ shown: Bool) {
        set(item.key, shown != item.inverted, in: item.domain)
        restart?.invalidate()
        restart = .after(0.6) {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            process.arguments = ["ControlCenter"]
            try? process.run()
        }
    }

    private static func bool(_ key: String, in domain: String) -> Bool? {
        CFPreferencesCopyAppValue(key as CFString, domain as CFString) as? Bool
    }

    private static func set(_ key: String, _ value: Bool, in domain: String) {
        CFPreferencesSetAppValue(key as CFString, value as CFBoolean, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }
}
