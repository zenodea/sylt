import SwiftUI

/// Three dots rippling in turn: the agent is thinking.
struct WorkingDots: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 30)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<3, id: \.self) { index in
                    let lift = max(0, sin(t * 2 * .pi / 1.2 - Double(index) * 0.9))
                    Circle()
                        .fill(.green)
                        .frame(width: 4, height: 4)
                        .offset(y: -lift * 3)
                        .opacity(0.5 + lift * 0.5)
                }
            }
        }
        .frame(height: 10, alignment: .bottom)
    }
}
