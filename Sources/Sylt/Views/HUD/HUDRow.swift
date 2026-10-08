import SwiftUI

/// A line of scrolling text under the notch while a two-row HUD shows.
struct HUDRow: View {
    let text: String

    var body: some View {
        MarqueeText(text: text)
            .foregroundStyle(.white.opacity(0.85))
            .frame(height: IslandLayout.hudRowHeight)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
    }
}
