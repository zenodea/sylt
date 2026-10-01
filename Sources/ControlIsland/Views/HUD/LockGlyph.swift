import SwiftUI

/// A drawn padlock: one body, one shackle. Opening lifts the shackle and
/// swings it out, so the lock animates in place rather than swapping icons.
struct LockGlyph: View {
    let open: Bool

    var body: some View {
        let tint: Color = open ? .green : .white.opacity(0.85)
        VStack(spacing: -1.5) {
            Shackle()
                .stroke(tint, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 7, height: 6.5)
                .rotationEffect(.degrees(open ? -28 : 0), anchor: .bottomLeading)
                .offset(y: open ? -2.5 : 0)
            RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                .fill(tint)
                .frame(width: 11, height: 8)
        }
        .frame(width: 13, height: 15, alignment: .bottom)
        .animation(IslandAnimation.unlock, value: open)
    }
}

private struct Shackle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let radius = rect.width / 2
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
        path.addArc(
            center: CGPoint(x: rect.midX, y: rect.minY + radius), radius: radius,
            startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        return path
    }
}
