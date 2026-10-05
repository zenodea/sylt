import SwiftUI

/// A plugin's items in a wing.
struct PluginBadge: View {
    let items: [PluginItem]
    var spacing: CGFloat = 8

    var body: some View {
        HStack(spacing: spacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                HStack(spacing: PluginItem.gap) {
                    if let status = item.status, item.symbol == nil, item.image == nil {
                        StatusMark(status: status, size: 6)
                    } else if let dot = item.dot {
                        Circle().fill(Color(tint: dot)).frame(width: 7, height: 7).shadow(color: Color(tint: dot).opacity(0.8), radius: 3)
                    }
                    if item.symbol != nil || item.image != nil {
                        PluginGlyph(symbol: item.symbol, image: item.image, tint: item.tint)
                            .saturation(item.status == "waiting" ? 0.2 : 1)
                            .opacity(item.status == "waiting" ? 0.45 : 1)
                            .overlay(alignment: .bottomTrailing) {
                                if let status = item.status {
                                    StatusMark(status: status, size: 5)
                                        .padding(0.5)
                                        .background(.black, in: Circle())
                                        .offset(x: 1.5, y: 1.5)
                                }
                            }
                    }
                    if let text = item.text, !text.isEmpty {
                        Text(text)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color(tint: item.tint ?? "white").opacity(item.tint == nil ? 0.85 : 1))
                            .monospacedDigit()
                            .lineLimit(1)
                            .fixedSize()
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
