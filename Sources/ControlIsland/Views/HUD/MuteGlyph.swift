import SwiftUI

/// Muting draws a slash through the speaker as it dips; unmuting wipes the slash
/// away. The waves fill with the level, so the symbol itself never changes.
struct MuteGlyph: View {
    let muted: Bool
    var level: Double = 1
    @State private var slash: CGFloat = 0

    var body: some View {
        Image(systemName: "speaker.wave.3.fill", variableValue: muted ? 0 : level)
            .font(.system(size: 13, weight: .semibold))
            .symbolEffect(.bounce.down, options: .nonRepeating, value: slash)
            .overlay {
                Slash()
                    .trim(from: 0, to: slash)
                    .stroke(.black, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                Slash()
                    .trim(from: 0, to: slash)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .onAppear {
                // Appear in the current state; only a change of state is animated.
                slash = muted ? 1 : 0
            }
            .onChange(of: muted) { _, muted in
                withAnimation(.easeOut(duration: 0.3)) { slash = muted ? 1 : 0 }
            }
    }
}

private struct Slash: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - 1, y: rect.minY - 1))
        path.addLine(to: CGPoint(x: rect.maxX + 1, y: rect.maxY + 1))
        return path
    }
}
