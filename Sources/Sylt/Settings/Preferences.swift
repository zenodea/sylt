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
    @Published var absorbsPointer: Bool
    @Published var holdsPointer: Bool
    @Published var releaseForce: Double
    @Published var releaseEffect: ReleaseEffect
    @Published var rippleStrength: Double
    @Published var showsRimGlow: Bool
    @Published var hapticsOnRelease: Bool
    @Published var wingLayout: WingLayout
    @Published var expandedLayout: ExpandedLayout

    private let defaults: UserDefaults
    private var cancellables = Set<AnyCancellable>()

    private enum Key {
        static let plugins = "enabledPlugins"
        static let overlays = "replacesSystemOverlays"
        static let huds = "enabledHUDs"
        static let hudDuration = "hudDurationScale"
        static let unlockSound = "playsUnlockSound"
        static let releaseEffect = "releaseEffect"
        static let absorbsPointer = "absorbsPointer"
        static let holdsPointer = "holdsPointer"
        static let releaseForce = "releaseForce"
        static let rippleStrength = "rippleStrength"
        static let rimGlow = "showsRimGlow"
        static let haptics = "hapticsOnRelease"
        static let knownPlugins = "knownPlugins"
        static let wingLayout = "wingLayout"
        static let expandedLayout = "expandedLayout"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Plugins added since the user last ran the app start out at their default.
        let known = Set(defaults.stringArray(forKey: Key.knownPlugins) ?? [])
        let plugins: Set<Plugin>
        if let stored = defaults.stringArray(forKey: Key.plugins) {
            plugins = Set(stored.compactMap(Plugin.init(rawValue:)))
                .union(Plugin.defaultEnabled.filter { !known.contains($0.rawValue) })
        } else {
            plugins = Plugin.defaultEnabled
        }
        enabledPlugins = plugins
        defaults.set(Plugin.allCases.map(\.rawValue), forKey: Key.knownPlugins)
        defaults.set(plugins.map(\.rawValue).sorted(), forKey: Key.plugins)
        replacesSystemOverlays = defaults.object(forKey: Key.overlays) as? Bool ?? true
        if let stored = defaults.stringArray(forKey: Key.huds) {
            enabledHUDs = Set(stored.compactMap(HUDCategory.init(rawValue:)))
        } else {
            enabledHUDs = Set(HUDCategory.allCases)
        }
        hudDurationScale = defaults.object(forKey: Key.hudDuration) as? Double ?? 1
        playsUnlockSound = defaults.object(forKey: Key.unlockSound) as? Bool ?? true
        releaseEffect = ReleaseEffect(rawValue: defaults.string(forKey: Key.releaseEffect) ?? "") ?? .ripple
        absorbsPointer = defaults.object(forKey: Key.absorbsPointer) as? Bool ?? true
        holdsPointer = defaults.object(forKey: Key.holdsPointer) as? Bool ?? true
        releaseForce = defaults.object(forKey: Key.releaseForce) as? Double ?? 1
        rippleStrength = defaults.object(forKey: Key.rippleStrength) as? Double ?? 1
        showsRimGlow = defaults.object(forKey: Key.rimGlow) as? Bool ?? true
        hapticsOnRelease = defaults.object(forKey: Key.haptics) as? Bool ?? true
        wingLayout = defaults.data(forKey: Key.wingLayout).flatMap { try? JSONDecoder().decode(WingLayout.self, from: $0) } ?? WingLayout()
        expandedLayout = defaults.data(forKey: Key.expandedLayout).flatMap { try? JSONDecoder().decode(ExpandedLayout.self, from: $0) } ?? ExpandedLayout()

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
        $releaseEffect
            .dropFirst()
            .sink { defaults.set($0.rawValue, forKey: Key.releaseEffect) }
            .store(in: &cancellables)
        $absorbsPointer
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.absorbsPointer) }
            .store(in: &cancellables)
        $holdsPointer
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.holdsPointer) }
            .store(in: &cancellables)
        $releaseForce
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.releaseForce) }
            .store(in: &cancellables)
        $rippleStrength
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.rippleStrength) }
            .store(in: &cancellables)
        $showsRimGlow
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.rimGlow) }
            .store(in: &cancellables)
        $hapticsOnRelease
            .dropFirst()
            .sink { defaults.set($0, forKey: Key.haptics) }
            .store(in: &cancellables)
        $wingLayout
            .dropFirst()
            .sink { defaults.set(try? JSONEncoder().encode($0), forKey: Key.wingLayout) }
            .store(in: &cancellables)
        $expandedLayout
            .dropFirst()
            .sink { defaults.set(try? JSONEncoder().encode($0), forKey: Key.expandedLayout) }
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

/// What the island does when it lets the pointer go.
enum ReleaseEffect: String, CaseIterable, Identifiable {
    case ripple = "splash", ring, glass, none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ripple: "Ripple"
        case .ring: "Ring of light"
        case .glass: "Liquid glass"
        case .none: "Nothing"
        }
    }
}
