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
    @Published var playsLockSound: Bool
    @Published var lockShowsStatus: Bool
    @Published var absorbsPointer: Bool
    @Published var holdsPointer: Bool
    @Published var releaseForce: Double
    @Published var releaseEffect: ReleaseEffect
    @Published var rippleStrength: Double
    @Published var rippleWidth: Double
    @Published var leansWithSwipes: Bool
    @Published var swipeLeanStrength: Double
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
        static let lockSound = "playsLockSound"
        static let lockStatus = "lockShowsStatus"
        static let releaseEffect = "releaseEffect"
        static let absorbsPointer = "absorbsPointer"
        static let holdsPointer = "holdsPointer"
        static let releaseForce = "releaseForce"
        static let rippleStrength = "rippleStrength"
        static let rippleWidth = "rippleWidth"
        static let swipeLean = "leansWithSwipes"
        static let swipeLeanStrength = "swipeLeanStrength"
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
        replacesSystemOverlays = defaults.value(Key.overlays, or: true)
        if let stored = defaults.stringArray(forKey: Key.huds) {
            enabledHUDs = Set(stored.compactMap(HUDCategory.init(rawValue:)))
        } else {
            enabledHUDs = Set(HUDCategory.allCases)
        }
        hudDurationScale = defaults.value(Key.hudDuration, or: 1)
        playsUnlockSound = defaults.value(Key.unlockSound, or: true)
        playsLockSound = defaults.value(Key.lockSound, or: true)
        lockShowsStatus = defaults.value(Key.lockStatus, or: false)
        releaseEffect = ReleaseEffect(rawValue: defaults.string(forKey: Key.releaseEffect) ?? "") ?? .ripple
        absorbsPointer = defaults.value(Key.absorbsPointer, or: true)
        holdsPointer = defaults.value(Key.holdsPointer, or: true)
        releaseForce = defaults.value(Key.releaseForce, or: 1)
        rippleStrength = defaults.value(Key.rippleStrength, or: 1)
        rippleWidth = defaults.value(Key.rippleWidth, or: 1)
        leansWithSwipes = defaults.value(Key.swipeLean, or: true)
        swipeLeanStrength = defaults.value(Key.swipeLeanStrength, or: 1)
        showsRimGlow = defaults.value(Key.rimGlow, or: true)
        hapticsOnRelease = defaults.value(Key.haptics, or: true)
        wingLayout = defaults.data(forKey: Key.wingLayout).flatMap { try? JSONDecoder().decode(WingLayout.self, from: $0) } ?? WingLayout()
        expandedLayout = defaults.data(forKey: Key.expandedLayout).flatMap { try? JSONDecoder().decode(ExpandedLayout.self, from: $0) } ?? ExpandedLayout()

        persist($enabledPlugins, as: Key.plugins) { $0.map(\.rawValue).sorted() }
        persist($replacesSystemOverlays, as: Key.overlays)
        persist($enabledHUDs, as: Key.huds) { $0.map(\.rawValue).sorted() }
        persist($hudDurationScale, as: Key.hudDuration)
        persist($playsUnlockSound, as: Key.unlockSound)
        persist($playsLockSound, as: Key.lockSound)
        persist($lockShowsStatus, as: Key.lockStatus)
        persist($releaseEffect, as: Key.releaseEffect, \.rawValue)
        persist($absorbsPointer, as: Key.absorbsPointer)
        persist($holdsPointer, as: Key.holdsPointer)
        persist($releaseForce, as: Key.releaseForce)
        persist($rippleStrength, as: Key.rippleStrength)
        persist($rippleWidth, as: Key.rippleWidth)
        persist($leansWithSwipes, as: Key.swipeLean)
        persist($swipeLeanStrength, as: Key.swipeLeanStrength)
        persist($showsRimGlow, as: Key.rimGlow)
        persist($hapticsOnRelease, as: Key.haptics)
        persist($wingLayout, as: Key.wingLayout) { try? JSONEncoder().encode($0) }
        persist($expandedLayout, as: Key.expandedLayout) { try? JSONEncoder().encode($0) }
    }

    private func persist<Value>(_ values: Published<Value>.Publisher, as key: String, _ stored: @escaping (Value) -> Any? = { $0 }) {
        values
            .dropFirst()
            .sink { [defaults] in defaults.set(stored($0), forKey: key) }
            .store(in: &cancellables)
    }

    func isEnabled(_ plugin: Plugin) -> Bool {
        enabledPlugins.contains(plugin)
    }

    func binding(for category: HUDCategory) -> Binding<Bool> {
        membership(\.enabledHUDs, of: category)
    }

    func binding(for plugin: Plugin) -> Binding<Bool> {
        membership(\.enabledPlugins, of: plugin)
    }

    private func membership<Element: Hashable>(_ set: ReferenceWritableKeyPath<Preferences, Set<Element>>, of element: Element) -> Binding<Bool> {
        Binding(
            get: { self[keyPath: set].contains(element) },
            set: { enabled in
                if enabled { self[keyPath: set].insert(element) } else { self[keyPath: set].remove(element) }
            }
        )
    }
}

private extension UserDefaults {
    func value<Value>(_ key: String, or fallback: Value) -> Value {
        object(forKey: key) as? Value ?? fallback
    }
}
