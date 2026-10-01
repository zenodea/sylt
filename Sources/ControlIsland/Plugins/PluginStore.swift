import Combine
import Foundation

/// Which external plugins are on, and their settings, in UserDefaults.
@MainActor
final class PluginStore: ObservableObject {
    @Published private(set) var enabled: Set<String>
    @Published private(set) var settings: [String: [String: JSONValue]]

    private let defaults: UserDefaults
    private static let enabledKey = "externalPluginsEnabled"
    private static let disabledKey = "externalPluginsDisabled"
    private static let settingsKey = "externalPluginSettings"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = Set(defaults.stringArray(forKey: Self.enabledKey) ?? [])
        let data = defaults.data(forKey: Self.settingsKey) ?? Data()
        settings = (try? JSONDecoder().decode([String: [String: JSONValue]].self, from: data)) ?? [:]
    }

    /// A plugin never seen before follows its manifest's default.
    func isEnabled(_ manifest: PluginManifest) -> Bool {
        if enabled.contains(manifest.id) { return true }
        if disabled.contains(manifest.id) { return false }
        return manifest.enabledByDefault ?? true
    }

    func setEnabled(_ on: Bool, _ manifest: PluginManifest) {
        var disabled = self.disabled
        if on { enabled.insert(manifest.id); disabled.remove(manifest.id) } else { enabled.remove(manifest.id); disabled.insert(manifest.id) }
        defaults.set(enabled.sorted(), forKey: Self.enabledKey)
        defaults.set(disabled.sorted(), forKey: Self.disabledKey)
    }

    func values(for manifest: PluginManifest) -> [String: JSONValue] {
        var values: [String: JSONValue] = [:]
        for setting in manifest.settings ?? [] { values[setting.key] = setting.default ?? .null }
        for (key, value) in settings[manifest.id] ?? [:] { values[key] = value }
        return values
    }

    func set(_ value: JSONValue, for key: String, in manifest: PluginManifest) {
        settings[manifest.id, default: [:]][key] = value
        if let data = try? JSONEncoder().encode(settings) { defaults.set(data, forKey: Self.settingsKey) }
    }

    private var disabled: Set<String> { Set(defaults.stringArray(forKey: Self.disabledKey) ?? []) }
}
