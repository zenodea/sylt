import XCTest
@testable import Sylt

@MainActor
final class PreferencesTests: XCTestCase {
    private func defaults() -> UserDefaults {
        let suite = "SyltTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testFreshInstallUsesDefaults() {
        let preferences = Preferences(defaults: defaults())
        XCTAssertEqual(preferences.enabledPlugins, Plugin.defaultEnabled)
        XCTAssertEqual(preferences.enabledHUDs, Set(HUDCategory.allCases))
        XCTAssertTrue(preferences.replacesSystemOverlays)
    }

    func testNewDefaultPluginsSwitchOnOnceForExistingInstalls() {
        let defaults = defaults()
        defaults.set(["battery"], forKey: "enabledPlugins")
        defaults.set(["battery", "volume"], forKey: "knownPlugins")
        let preferences = Preferences(defaults: defaults)
        XCTAssertTrue(preferences.enabledPlugins.contains(.battery))
        XCTAssertFalse(preferences.enabledPlugins.contains(.volume), "a known default the user turned off stays off")
        XCTAssertTrue(preferences.enabledPlugins.contains(.calendar), "an unseen default switches on")
        XCTAssertFalse(preferences.enabledPlugins.contains(.notifications), "non-default plugins stay off")

        preferences.enabledPlugins.remove(.calendar)
        let again = Preferences(defaults: defaults)
        XCTAssertFalse(again.enabledPlugins.contains(.calendar), "once seen, a plugin is never forced on again")
    }

    func testTogglesPersist() {
        let defaults = defaults()
        let preferences = Preferences(defaults: defaults)
        preferences.binding(for: Plugin.volume).wrappedValue = false
        preferences.binding(for: HUDCategory.unlock).wrappedValue = false
        preferences.hudDurationScale = 1.5
        let reloaded = Preferences(defaults: defaults)
        XCTAssertFalse(reloaded.enabledPlugins.contains(.volume))
        XCTAssertFalse(reloaded.enabledHUDs.contains(.unlock))
        XCTAssertEqual(reloaded.hudDurationScale, 1.5)
    }
}
