import SwiftUI

struct AppearancePane: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Section("Shape") {
            SymbolSlider("Depth below the notch", value: $preferences.notchDepth, in: 0...8, step: 1, symbol: "rectangle.topthird.inset.filled")
            SymbolSlider("Corner radius, closed", value: $preferences.cornerRadius, in: 0...40, step: 1, low: "square", high: "circle")
            SymbolSlider("Corner radius, open", value: $preferences.openCornerRadius, in: 0...40, step: 1, low: "square", high: "circle")
        }
        Section("Glass") {
            Toggle("Frosted glass at the edges", isOn: $preferences.frostedEdges)
            if preferences.frostedEdges {
                if GlassCard.isAvailable {
                    glassKind("Kind", selection: $preferences.liquidGlass)
                }
                ColorPicker("Tint", selection: $preferences.glassTint, supportsOpacity: true)
            }
        }
        if preferences.frostedEdges {
            glassSection("Glass when closed", width: $preferences.glassReachWidth, height: $preferences.glassReachHeight,
                         opacity: $preferences.glassOpacity, blur: $preferences.glassBlur)
            glassSection("Glass when open", width: $preferences.openGlassReachWidth, height: $preferences.openGlassReachHeight,
                         opacity: $preferences.openGlassOpacity, blur: $preferences.openGlassBlur)
        }
        Section("Open island") {
            Toggle("Open pages side by side when the screen has room", isOn: $preferences.spreadsPages)
            if GlassCard.isAvailable {
                Toggle("Each section on its own glass", isOn: $preferences.glassCards)
                if preferences.glassCards {
                    glassKind("Card glass", selection: $preferences.liquidCards)
                    opacitySlider("Glass opacity", value: $preferences.glassCardOpacity)
                }
            }
        }
    }

    private func glassSection(_ title: String, width: Binding<Double>, height: Binding<Double>, opacity: Binding<Double>, blur: Binding<Double>) -> some View {
        Section(title) {
            SymbolSlider("Across", value: width, in: 0...1, step: 0.05, symbol: "arrow.left.and.right")
            SymbolSlider("Up", value: height, in: 0...1, step: 0.05, symbol: "arrow.up.and.down")
            opacitySlider("Opacity", value: opacity)
            if preferences.liquidGlass {
                SymbolSlider("Blur", value: blur, in: 0...1, step: 0.05, low: "drop", high: "drop.fill")
            }
        }
    }

    private func glassKind(_ title: String, selection: Binding<Bool>) -> some View {
        Picker(title, selection: selection) {
            Text("Frosted").tag(false)
            Text("Liquid Glass").tag(true)
        }
    }

    private func opacitySlider(_ title: String, value: Binding<Double>) -> some View {
        SymbolSlider(title, value: value, in: 0.1...1, step: 0.05, low: "circle.dotted", high: "circle.fill")
    }
}
