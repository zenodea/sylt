import SwiftUI

/// A row of thin bars for values from 0 to 1, oldest on the left, the latest bright.
struct Sparkline: View {
    let values: [Double]
    var tint: Color = .white

    var body: some View {
        Canvas { context, size in
            let count = max(values.count, 1)
            let slot = size.width / CGFloat(count)
            let width = max(1, slot * 0.6)
            for (index, value) in values.enumerated() {
                let height = max(1.5, size.height * CGFloat(min(max(value, 0), 1)))
                let rect = CGRect(x: CGFloat(index) * slot + (slot - width) / 2, y: size.height - height, width: width, height: height)
                let fade = 0.35 + 0.65 * Double(index + 1) / Double(count)
                context.fill(Path(roundedRect: rect, cornerRadius: width / 2), with: .color(tint.opacity(fade)))
            }
        }
        .animation(IslandAnimation.value, value: values)
    }
}
