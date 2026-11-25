import SwiftUI

/// Light has no business on the screen's edge: where the island lies along it (the top under
/// a notch, two sides in a corner), anything glowing fades out over the first few points.
struct FadeEdges: ViewModifier {
    let flush: FlushEdges
    let canvas: CGSize

    private static let depth: CGFloat = 12

    func body(content: Content) -> some View {
        content
            .mask(fade(flush.contains(.top), length: canvas.height, from: .top, to: .bottom))
            .mask(fade(flush.contains(.bottom), length: canvas.height, from: .bottom, to: .top))
            .mask(fade(flush.contains(.leading), length: canvas.width, from: .leading, to: .trailing))
            .mask(fade(flush.contains(.trailing), length: canvas.width, from: .trailing, to: .leading))
    }

    private func fade(_ enabled: Bool, length: CGFloat, from start: UnitPoint, to end: UnitPoint) -> LinearGradient {
        let reach = min(Self.depth / max(length, 1), 1)
        return LinearGradient(stops: [.init(color: enabled ? .clear : .white, location: 0), .init(color: .white, location: reach)], startPoint: start, endPoint: end)
    }
}

extension View {
    func fadeEdges(_ flush: FlushEdges, in canvas: CGSize) -> some View { modifier(FadeEdges(flush: flush, canvas: canvas)) }
}
