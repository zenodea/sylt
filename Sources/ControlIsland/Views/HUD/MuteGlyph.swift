import SwiftUI

/// Muting draws a slash through the speaker as it dips; unmuting wipes the
/// slash away and the sound waves light up again.
struct MuteGlyph: View {
    let muted: Bool
    @State private var slash: CGFloat = 0
    @State private var waves = false

    var body: some View {
        Image(systemName: muted ? "speaker.fill" : "speaker.wave.2.fill")
            .font(.system(size: 13, weight: .semibold))
            .symbolEffect(.variableColor.iterative, options: .nonRepeating, value: waves)
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
                slash = muted ? 0 : 1
                withAnimation(.easeOut(duration: 0.3).delay(0.15)) { slash = muted ? 1 : 0 }
                if !muted { waves = true }
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
