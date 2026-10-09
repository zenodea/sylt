import SwiftUI

/// Four bars dancing while something plays. Drawn in a canvas: a frame changes only
/// pixels, never the layout, so the island isn't laid out again at every tick.
struct AudioBars: View {
    static let barCount = 4
    static let barWidth: CGFloat = 2.5
    static let spacing: CGFloat = 2
    /// The bars' laid-out width, for wing sizing.
    static let width = CGFloat(barCount) * barWidth + CGFloat(barCount - 1) * spacing

    let isPlaying: Bool
    var colors: [Color] = [.white]
    var height: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            Canvas { graphics, size in
                for index in 0..<Self.barCount {
                    let barHeight = self.barHeight(index: index, time: time)
                    let rect = CGRect(
                        x: CGFloat(index) * (Self.barWidth + Self.spacing), y: (size.height - barHeight) / 2,
                        width: Self.barWidth, height: barHeight
                    )
                    graphics.fill(Capsule().path(in: rect), with: .color(colors[index % colors.count]))
                }
            }
        }
        .frame(width: Self.width, height: height)
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return height * 0.25 }
        let phase = Double(index) * 1.3
        let wave = (sin(time * 7 + phase) + sin(time * 11.3 + phase * 2.1)) / 4 + 0.5
        return height * (0.25 + 0.75 * wave)
    }
}
