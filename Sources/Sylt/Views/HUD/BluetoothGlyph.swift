import SwiftUI

struct BluetoothGlyph: View {
    let connected: Bool
    @State private var drawn: CGFloat = 0
    @State private var ring: CGFloat = 0
    @State private var dropped = false

    var body: some View {
        ZStack {
            ForEach(0..<2, id: \.self) { index in
                Circle()
                    .stroke(.blue.opacity(0.6), lineWidth: 1)
                    .scaleEffect(0.6 + ring * 1.2)
                    .opacity(connected ? (1 - ring) * 0.8 : 0)
                    .animation(.easeOut(duration: 0.9).delay(Double(index) * 0.25), value: ring)
            }
            Rune()
                .trim(from: 0, to: drawn)
                .stroke(dropped ? Color.white.opacity(0.45) : .blue, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                .frame(width: 8, height: 15)
                .scaleEffect(dropped ? 0.85 : 1)
                .offset(y: dropped ? 2 : 0)
        }
        .frame(width: 18, height: 18)
        .onAppear {
            drawn = connected ? 0 : 1
            if connected {
                withAnimation(.easeInOut(duration: 0.55).delay(0.15)) { drawn = 1 }
                ring = 1
            } else {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.45).delay(0.2)) { dropped = true }
            }
        }
    }
}

struct RuneMark: View {
    var color: Color = .blue
    var lineWidth: CGFloat = 2
    var height: CGFloat = 15

    var body: some View {
        Rune()
            .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, lineJoin: .round))
            .frame(width: height * 8 / 15, height: height)
            .frame(width: 16, height: 16)
    }
}

private struct Rune: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: 0, y: h * 0.25))
        path.addLine(to: CGPoint(x: w, y: h * 0.75))
        path.addLine(to: CGPoint(x: w / 2, y: h))
        path.addLine(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.25))
        path.addLine(to: CGPoint(x: 0, y: h * 0.75))
        return path
    }
}
