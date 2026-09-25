import SwiftUI

struct LevelBar: View {
    var value: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.2))
                Capsule().fill(.white).frame(width: geo.size.width * value)
            }
        }
        .frame(height: 6)
    }
}
