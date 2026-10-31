import SwiftUI

struct InteractionPane: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Section("Pointer") {
            Toggle("Glow as the pointer comes near", isOn: $preferences.approachGlow)
            Toggle("Take the pointer in", isOn: $preferences.absorbsPointer)
            if preferences.absorbsPointer {
                Toggle("Hold it until pushed", isOn: $preferences.holdsPointer)
                if preferences.holdsPointer {
                    SymbolSlider("Push needed", value: $preferences.releaseForce, in: 0.4...2, step: 0.2, low: "hand.point.up.left", high: "hand.point.up.left.fill")
                    Toggle("Glow at the edge where it would come out", isOn: $preferences.showsRimGlow)
                }
            }
        }
        if preferences.absorbsPointer {
            Section("Letting go") {
                Picker("Effect", selection: $preferences.releaseEffect) {
                    ForEach(ReleaseEffect.allCases) { Text($0.title).tag($0) }
                }
                if preferences.releaseEffect == .ripple {
                    SymbolSlider("Ripple strength", value: $preferences.rippleStrength, in: 0.5...2.5, step: 0.25, symbol: "water.waves")
                    SymbolSlider("Ripple width", value: $preferences.rippleWidth, in: 0.5...3, step: 0.25, symbol: "arrow.left.and.right")
                }
                Toggle("Haptic tap", isOn: $preferences.hapticsOnRelease)
            }
        }
        Section("Swipes") {
            Toggle("Lean with swipes", isOn: $preferences.leansWithSwipes)
            if preferences.leansWithSwipes {
                SymbolSlider("How far", value: $preferences.swipeLeanStrength, in: 0.25...2, step: 0.25, symbol: "arrow.left.and.right")
            }
        }
    }
}
