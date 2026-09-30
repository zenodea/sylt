import SwiftUI

/// A symbol that bounces in when a HUD opens.
struct HUDGlyph: View {
    let symbol: String
    var tint: Color = .white
    var size: CGFloat = 14
    @State private var shown = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .semibold))
            .foregroundStyle(tint)
            .symbolEffect(.bounce, options: .nonRepeating, value: shown)
            .onAppear { shown = true }
    }
}

/// Short right-side HUD text.
struct HUDLabel: View {
    let text: String
    var dimmed = false

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(dimmed ? Color.white.opacity(0.6) : .white)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
