import SwiftUI

struct NetworkGlyph: View {
    let link: NetworkMonitor.Link
    @State private var shown = false

    var body: some View {
        Image(systemName: link.symbol)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(link == .offline ? Color.white.opacity(0.6) : .white)
            .symbolEffect(.variableColor.iterative, options: .nonRepeating, value: shown)
            .symbolEffect(.bounce, options: .nonRepeating, value: shown)
            .onAppear { shown = true }
    }
}
