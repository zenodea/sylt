import SwiftUI

/// A ring that expands and fades at the rim where the pointer just left.
struct ReleaseBurst: View {
    let point: CGPoint
    @State private var fired = false

    var body: some View {
        Circle()
            .stroke(.white.opacity(fired ? 0 : 0.7), lineWidth: fired ? 1 : 3)
            .background(Circle().fill(.white.opacity(fired ? 0 : 0.25)))
            .frame(width: 24, height: 24)
            .scaleEffect(fired ? 3.2 : 0.4)
            .position(point)
            .allowsHitTesting(false)
            .onAppear { withAnimation(.easeOut(duration: 0.45)) { fired = true } }
    }
}
