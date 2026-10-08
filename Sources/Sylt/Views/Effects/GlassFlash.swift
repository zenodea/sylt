import SwiftUI

/// The island as thick dark glass: light catches the rim where the pointer left and a
/// reflection sweeps back across the surface, away from the exit, then fades.
struct GlassFlash: View {
    let shape: IslandShape
    let point: CGPoint
    let direction: CGVector
    @State private var fired = false

    var body: some View {
        ZStack {
            Ellipse()
                .fill(RadialGradient(colors: [.white.opacity(0.7), .white.opacity(0.16), .clear], center: .center, startRadius: 0, endRadius: 70))
                .frame(width: 220, height: 56)
                .rotationEffect(.radians(atan2(direction.dy, direction.dx) * 0.3))
                .blur(radius: 8)
                .position(x: point.x - direction.dx * (fired ? 150 : 10), y: point.y - direction.dy * (fired ? 60 : 4))
                .opacity(fired ? 0 : 1)
            RimOutline(shape: shape)
                .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .blur(radius: 0.6)
                .mask(
                    Circle()
                        .fill(RadialGradient(colors: [.white, .white.opacity(0.5), .clear], center: .center, startRadius: 0, endRadius: 80))
                        .frame(width: 160, height: 160)
                        .scaleEffect(fired ? 2.4 : 0.6)
                        .position(point)
                )
                .opacity(fired ? 0 : 0.95)
        }
        .blendMode(.plusLighter)
        .allowsHitTesting(false)
        .onAppear { withAnimation(.easeOut(duration: 0.6)) { fired = true } }
    }
}
