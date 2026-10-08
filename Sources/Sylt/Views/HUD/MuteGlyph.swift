import SwiftUI

/// The slash is drawn and wiped over one symbol whose waves fill with the level, so nothing ever swaps.
struct MuteGlyph: View {
    let muted: Bool
    var level: Double = 1
    /// Sound is going to a Bluetooth device: the rune stands in for the speaker.
    var bluetooth = false
    @State private var slash: CGFloat = 0

    var body: some View {
        Group {
            if bluetooth {
                RuneMark().opacity(muted ? 0.45 : 1)
            } else {
                Image(systemName: "speaker.wave.3.fill", variableValue: muted ? 0 : level)
                    .font(.system(size: 13, weight: .semibold))
            }
        }
            .symbolEffect(.bounce.down, options: .nonRepeating, value: slash)
            .overlay {
                Slash()
                    .trim(from: 0, to: slash)
                    .stroke(.black, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                Slash()
                    .trim(from: 0, to: slash)
                    .stroke(.white, style: StrokeStyle(lineWidth: 2, lineCap: .round))
            }
            .onAppear { slash = muted ? 1 : 0 }
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
