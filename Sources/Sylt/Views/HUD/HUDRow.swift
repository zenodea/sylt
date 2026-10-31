import SwiftUI

struct HUDRow: View {
    let title: String
    let detail: String

    var body: some View {
        MarqueeText(text: detail.isEmpty ? title : "\(title)  ·  \(detail)")
            .foregroundStyle(.white.opacity(0.85))
            .frame(height: IslandLayout.hudRowHeight)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
    }
}
