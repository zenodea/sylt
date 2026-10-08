import SwiftUI

struct EffectsPane: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Section("Pointer") {
            Toggle("Take the pointer in", isOn: $preferences.absorbsPointer)
            if preferences.absorbsPointer {
                Toggle("Hold it until pushed", isOn: $preferences.holdsPointer)
                if preferences.holdsPointer {
                    StrengthSlider("Push needed", value: $preferences.releaseForce, in: 0.4...2, step: 0.2, low: "hand.point.up.left", high: "hand.point.up.left.fill")
                    Toggle("Glow at the edge where it would come out", isOn: $preferences.showsRimGlow)
                }
            }
        }
        Section("Swipes") {
            Toggle("Lean with swipes", isOn: $preferences.leansWithSwipes)
            if preferences.leansWithSwipes {
                StrengthSlider("How far", value: $preferences.swipeLeanStrength, in: 0.25...2, step: 0.25, symbol: "arrow.left.and.right")
            }
        }
        if preferences.absorbsPointer {
            Section("Letting go") {
                Picker("Effect", selection: $preferences.releaseEffect) {
                    ForEach(ReleaseEffect.allCases) { Text($0.title).tag($0) }
                }
                if preferences.releaseEffect == .ripple {
                    StrengthSlider("Ripple strength", value: $preferences.rippleStrength, in: 0.5...2.5, step: 0.25, symbol: "water.waves")
                    StrengthSlider("Ripple width", value: $preferences.rippleWidth, in: 0.5...3, step: 0.25, symbol: "arrow.left.and.right")
                }
                Toggle("Haptic tap", isOn: $preferences.hapticsOnRelease)
            }
        }
    }
}

/// A stepped slider between a small and a large symbol.
private struct StrengthSlider: View {
    let title: String
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let low: String
    let high: String

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, low: String, high: String) {
        self.title = title
        self.value = value
        self.range = range
        self.step = step
        self.low = low
        self.high = high
    }

    init(_ title: String, value: Binding<Double>, in range: ClosedRange<Double>, step: Double, symbol: String) {
        self.init(title, value: value, in: range, step: step, low: symbol, high: symbol)
    }

    var body: some View {
        Slider(value: value, in: range, step: step) {
            Text(title)
        } minimumValueLabel: {
            Image(systemName: low).imageScale(.small)
        } maximumValueLabel: {
            Image(systemName: high).imageScale(.large)
        }
    }
}
