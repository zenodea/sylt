import SwiftUI

/// Text that doesn't fit starts at its beginning and slides left to reveal the end,
/// pausing briefly at the start of each pass.
struct MarqueeText: View {
    let text: String
    var font: Font = .system(size: 11, weight: .medium, design: .rounded)
    var speed: Double = 30

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0

    var body: some View {
        GeometryReader { container in
            TimelineView(.animation(paused: textWidth <= containerWidth)) { context in
                let overflow = max(0, textWidth - containerWidth)
                let cycle = overflow / speed + 2.5
                let t = context.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: cycle)
                let offset = -min(overflow, max(0, t - 1.5) * speed)
                Text(text)
                    .font(font)
                    .lineLimit(1)
                    .fixedSize()
                    .background(GeometryReader { proxy in
                        Color.clear.onChange(of: proxy.size.width, initial: true) { textWidth = proxy.size.width }
                    })
                    .offset(x: offset)
            }
            .onChange(of: container.size.width, initial: true) { containerWidth = container.size.width }
        }
        .clipped()
    }
}
