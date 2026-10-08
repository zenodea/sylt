import SwiftUI

struct OverlaysPane: View {
    @ObservedObject var preferences: Preferences

    var body: some View {
        Section("Overlays") {
            ForEach(HUDCategory.allCases) { category in
                Toggle(isOn: preferences.binding(for: category)) {
                    Label(category.title, systemImage: category.symbol)
                }
                .toggleStyle(.switch)
            }
        }
        Section("Timing") {
            LabeledContent("Overlay duration") {
                HStack(spacing: 10) {
                    Slider(value: $preferences.hudDurationScale, in: 0.6...2.5)
                        .frame(width: 180)
                    Text(String(format: "%.1f×", preferences.hudDurationScale))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }
}
