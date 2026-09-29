import SwiftUI

/// The island outline, hugging the top of its rect, centred on the notch plus
/// an offset. Animates size and offset without moving the content behind it.
struct IslandShape: Shape {
    var frame: IslandFrame
    var notchHeight: CGFloat

    var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>, CGFloat> {
        get { AnimatablePair(AnimatablePair(frame.size.width, frame.size.height), frame.centerOffset) }
        set { frame = IslandFrame(size: CGSize(width: newValue.first.first, height: newValue.first.second), centerOffset: newValue.second) }
    }

    func path(in rect: CGRect) -> Path {
        let size = frame.size
        let origin = CGPoint(x: rect.midX - size.width / 2 + frame.centerOffset, y: rect.minY)
        let opened = max(0, size.height - notchHeight)
        let radius = min(10 + opened * 0.35, 28, size.height / 2)
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        ).path(in: CGRect(origin: origin, size: size))
    }
}
