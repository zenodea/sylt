import SwiftUI

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
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: Self.spacing) {
                ForEach(0..<Self.barCount, id: \.self) { index in
                    Capsule()
                        .fill(colors[index % colors.count])
                        .frame(width: Self.barWidth, height: barHeight(index: index, time: time))
                }
            }
            .frame(width: Self.width, height: height)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return height * 0.25 }
        let phase = Double(index) * 1.3
        let wave = (sin(time * 7 + phase) + sin(time * 11.3 + phase * 2.1)) / 4 + 0.5
        return height * (0.25 + 0.75 * wave)
    }
}
