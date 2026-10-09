import SwiftUI

/// The rim lighting up inside the island where the pointer would come out or come in,
/// brighter the closer or the harder the push.
struct RimGlow: View {
    let shape: IslandShape
    let point: CGPoint
    let strength: CGFloat

    var body: some View {
        RimOutline(shape: shape)
            .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .blur(radius: 1.5)
            .mask(
                Circle()
                    .fill(RadialGradient(colors: [.white, .white.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 46))
                    .frame(width: 92, height: 92)
                    .position(point)
            )
            .opacity(strength > 0.03 ? 0.15 + strength * 0.85 : 0)
            .animation(IslandAnimation.cursor, value: point)
            .animation(IslandAnimation.cursor, value: strength)
            .allowsHitTesting(false)
    }
}
