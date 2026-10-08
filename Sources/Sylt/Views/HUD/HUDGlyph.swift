import SwiftUI

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

struct HUDLabel: View {
    let text: String
    var dimmed = false

    var body: some View {
        Text(text)
            .font(.badge)
            .foregroundStyle(dimmed ? Color.white.opacity(0.6) : .white)
            .lineLimit(1)
            .truncationMode(.tail)
    }
}
