import Combine
import Foundation
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    @Published var enabledPlugins: Set<Plugin>
    @Published var replacesSystemOverlays: Bool

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    private enum Key {
        static let plugins = "enabledPlugins"
        static let overlays = "replacesSystemOverlays"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let stored = defaults.stringArray(forKey: Key.plugins) {
            enabledPlugins = Set(stored.compactMap(Plugin.init(rawValue:)))
        } else {
            enabledPlugins = Plugin.defaultEnabled
        }
        replacesSystemOverlays = defaults.object(forKey: Key.overlays) as? Bool ?? true

        $enabledPlugins
            .dropFirst()
            .sink { defaults.set($0.map(\.rawValue).sorted(), forKey: Key.plugins) }
            .store(in: &cancellables)
        $replacesSystemOverlays
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.overlays) }
            .store(in: &cancellables)
    }

    func isEnabled(_ plugin: Plugin) -> Bool {
        enabledPlugins.contains(plugin)
    }

    func binding(for plugin: Plugin) -> Binding<Bool> {
        Binding(
            get: { self.enabledPlugins.contains(plugin) },
            set: { enabled in
                if enabled { self.enabledPlugins.insert(plugin) } else { self.enabledPlugins.remove(plugin) }
            }
        )
    }
}
