import SwiftUI

struct AudioBars: View {
    let isPlaying: Bool
    var barCount = 4
    var height: CGFloat = 14

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30, paused: !isPlaying)) { context in
            let time = context.date.timeIntervalSinceReferenceDate
            HStack(alignment: .center, spacing: 2) {
                ForEach(0..<barCount, id: \.self) { index in
                    Capsule()
                        .fill(.white)
                        .frame(width: 2.5, height: barHeight(index: index, time: time))
                }
            }
            .frame(height: height)
        }
    }

    private func barHeight(index: Int, time: TimeInterval) -> CGFloat {
        guard isPlaying else { return height * 0.25 }
        let phase = Double(index) * 1.3
        let wave = (sin(time * 7 + phase) + sin(time * 11.3 + phase * 2.1)) / 4 + 0.5
        return height * (0.25 + 0.75 * wave)
    }
}
