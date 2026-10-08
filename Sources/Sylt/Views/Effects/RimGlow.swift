import SwiftUI

/// The rim lighting up where the held pointer would come out, brighter the harder it is
/// pushed. The stretch under the notch stays dark: light there outlines the notch.
struct RimGlow: View {
    let shape: IslandShape
    let point: CGPoint
    let strength: CGFloat
    var notchWidth: CGFloat = 0

    var body: some View {
        RimOutline(shape: shape)
            .stroke(.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
            .blur(radius: 1.5)
            .mask(
                GeometryReader { geometry in
                    ZStack {
                        Circle()
                            .fill(RadialGradient(colors: [.white, .white.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 46))
                            .frame(width: 92, height: 92)
                            .position(point)
                        Rectangle()
                            .frame(width: notchWidth + IslandLayout.sideOverlap * 2 + 8, height: geometry.size.height)
                            .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                }
            )
            .opacity(strength > 0.03 ? 0.15 + strength * 0.85 : 0)
            .animation(IslandAnimation.cursor, value: point)
            .animation(IslandAnimation.cursor, value: strength)
            .allowsHitTesting(false)
    }
}
