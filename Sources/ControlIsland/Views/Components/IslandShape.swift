import SwiftUI

struct IslandShape: Shape {
    var notchHeight: CGFloat

    func path(in rect: CGRect) -> Path {
        let opened = max(0, rect.height - notchHeight)
        let radius = min(10 + opened * 0.35, 28, rect.height / 2)
        return UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: radius,
            bottomTrailingRadius: radius,
            topTrailingRadius: 0,
            style: .continuous
        ).path(in: rect)
    }
}
