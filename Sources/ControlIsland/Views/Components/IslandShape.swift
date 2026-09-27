import SwiftUI

/// The island outline, drawn at `size` hugging the top centre of its rect so it
/// can animate without ever moving the content laid out behind it.
struct IslandShape: Shape {
    var size: CGSize
    var notchHeight: CGFloat

    var animatableData: AnimatablePair<CGFloat, CGFloat> {
        get { AnimatablePair(size.width, size.height) }
        set { size = CGSize(width: newValue.first, height: newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let frame = CGRect(x: rect.midX - size.width / 2, y: rect.minY, width: size.width, height: size.height)
        let opened = max(0, size.height - notchHeight)
        let radius = min(10 + opened * 0.35, 28, size.height / 2)
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        ).path(in: frame)
    }
}
