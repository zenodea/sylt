import SwiftUI

/// An accessory's charge: the percentage beside a small gauge that fills to
/// that exact level when it appears.
struct DeviceBattery: View {
    let percent: Int
    @State private var fill: CGFloat = 0

    private static let gaugeWidth: CGFloat = 20
    private static let gaugeHeight: CGFloat = 10
    /// "100%" plus the gauge, for wing sizing.
    static let width: CGFloat = TextWidth.of("100%", size: 11) + 6 + gaugeWidth + 2.5

    var body: some View {
        HStack(spacing: 6) {
            Text("\(percent)%")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
            gauge
        }
        .foregroundStyle(.white.opacity(0.85))
        .fixedSize()
        .onAppear { withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(0.2)) { fill = CGFloat(percent) / 100 } }
    }

    private var gauge: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .stroke(.white.opacity(0.45), lineWidth: 1)
            .frame(width: Self.gaugeWidth, height: Self.gaugeHeight)
            .overlay(alignment: .leading) {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(tint)
                    .frame(width: max(1.5, (Self.gaugeWidth - 4) * fill), height: Self.gaugeHeight - 4)
                    .padding(.leading, 2)
            }
            .overlay(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 1, style: .continuous)
                    .fill(.white.opacity(0.45))
                    .frame(width: 1.5, height: 4)
                    .offset(x: 2.5)
            }
            .padding(.trailing, 2.5)
    }

    private var tint: Color {
        switch percent {
        case ...20: .red
        case ...40: .yellow
        default: .green
        }
    }
}
