import Combine
import Foundation
import SwiftUI

@MainActor
final class Preferences: ObservableObject {
    @Published var enabledPlugins: Set<Plugin>
    @Published var replacesSystemOverlays: Bool
    @Published var enabledHUDs: Set<HUDCategory>
    @Published var hudDurationScale: Double
    @Published var playsUnlockSound: Bool

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    private enum Key {
        static let plugins = "enabledPlugins"
        static let overlays = "replacesSystemOverlays"
        static let huds = "enabledHUDs"
        static let hudDuration = "hudDurationScale"
        static let unlockSound = "playsUnlockSound"
        static let knownPlugins = "knownPlugins"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Plugins added since the user last ran the app start out at their default.
        let known = Set(defaults.stringArray(forKey: Key.knownPlugins) ?? [])
        if let stored = defaults.stringArray(forKey: Key.plugins) {
            enabledPlugins = Set(stored.compactMap(Plugin.init(rawValue:)))
                .union(Plugin.defaultEnabled.filter { !known.contains($0.rawValue) })
        } else {
            enabledPlugins = Plugin.defaultEnabled
        }
        defaults.set(Plugin.allCases.map(\.rawValue), forKey: Key.knownPlugins)
        replacesSystemOverlays = defaults.object(forKey: Key.overlays) as? Bool ?? true
        if let stored = defaults.stringArray(forKey: Key.huds) {
            enabledHUDs = Set(stored.compactMap(HUDCategory.init(rawValue:)))
        } else {
            enabledHUDs = Set(HUDCategory.allCases)
        }
        hudDurationScale = defaults.object(forKey: Key.hudDuration) as? Double ?? 1
        playsUnlockSound = defaults.object(forKey: Key.unlockSound) as? Bool ?? true

        $enabledPlugins
            .dropFirst()
            .sink { defaults.set($0.map(\.rawValue).sorted(), forKey: Key.plugins) }
            .store(in: &cancellables)
        $replacesSystemOverlays
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.overlays) }
            .store(in: &cancellables)
        $enabledHUDs
            .dropFirst()
            .sink { defaults.set($0.map(\.rawValue).sorted(), forKey: Key.huds) }
            .store(in: &cancellables)
        $hudDurationScale
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.hudDuration) }
            .store(in: &cancellables)
        $playsUnlockSound
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.unlockSound) }
            .store(in: &cancellables)
    }

    func isEnabled(_ plugin: Plugin) -> Bool {
        enabledPlugins.contains(plugin)
    }

    func binding(for category: HUDCategory) -> Binding<Bool> {
        Binding(
            get: { self.enabledHUDs.contains(category) },
            set: { enabled in
                if enabled { self.enabledHUDs.insert(category) } else { self.enabledHUDs.remove(category) }
            }
        )
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
