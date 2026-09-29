import SwiftUI

struct LevelBar: View {
    var value: Double
    var tint: Color = .white

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(tint).frame(width: geo.size.width * min(max(value, 0), 1))
            }
            .animation(IslandAnimation.value, value: value)
        }
        .frame(height: 6)
    }
}
