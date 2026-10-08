import SwiftUI

/// Light has no business on the island's top edge, which is the screen's edge: anything
/// glowing there fades out over the first few points.
struct FadeTop: ViewModifier {
    func body(content: Content) -> some View {
        content.mask(
            VStack(spacing: 0) {
                LinearGradient(colors: [.clear, .white], startPoint: .top, endPoint: .bottom).frame(height: 12)
                Color.white
            }
        )
    }
}

extension View {
    func fadeTop() -> some View { modifier(FadeTop()) }
}
