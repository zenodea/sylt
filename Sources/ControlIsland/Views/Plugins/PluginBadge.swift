import SwiftUI

/// A plugin's items in a wing.
struct PluginBadge: View {
    let items: [PluginItem]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: PluginItem.gap) {
                    if item.symbol != nil || item.image != nil {
                        PluginGlyph(symbol: item.symbol, image: item.image, tint: item.tint)
                    }
                    if let text = item.text, !text.isEmpty {
                        Text(text)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(tint: item.tint ?? "white").opacity(item.tint == nil ? 0.85 : 1))
                            .monospacedDigit()
                            .lineLimit(1)
                    }
                    if let status = item.status {
                        StatusDot(working: status == "working", size: 6)
                    } else if let dot = item.dot {
                        Circle().fill(Color(tint: dot)).frame(width: 7, height: 7).shadow(color: Color(tint: dot).opacity(0.8), radius: 3)
                    }
                    if let ring = item.ring {
                        TimerRing(fraction: ring, size: 12)
                    }
                }
            }
        }
        .animation(IslandAnimation.value, value: items)
    }
}
