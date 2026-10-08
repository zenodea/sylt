import SwiftUI

struct PopGlyph: View {
    let symbol: String
    var tint: Color = .green
    @State private var shown = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(tint)
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(IslandAnimation.unlock.delay(0.25)) { shown = true } }
    }
}
