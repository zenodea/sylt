import SwiftUI

/// A small screen with the island's eight snap targets: four corners and the middle of each
/// edge. A placement dragged somewhere else along an edge shows as none of them.
struct PlacementPicker: View {
    @Binding var placement: IslandPlacement

    private static let screen = CGSize(width: 240, height: 140)
    private static let target = CGSize(width: 34, height: 14)
    private static let inset: CGFloat = 6

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(LinearGradient(colors: [Color(red: 0.8, green: 0.84, blue: 1), Color(red: 0.91, green: 0.92, blue: 0.95)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.primary.opacity(0.15)))
                ForEach(IslandPlacement.targets.indices, id: \.self) { index in
                    button(for: IslandPlacement.targets[index])
                }
            }
            .frame(width: Self.screen.width, height: Self.screen.height)
            Text(Self.describe(placement))
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private func button(for target: IslandPlacement) -> some View {
        let chosen = target == placement
        let shape = Self.shape(for: target)
        return Button {
            withAnimation(IslandAnimation.value) { placement = target }
        } label: {
            shape.fill(chosen ? Color.accentColor : Color.black.opacity(0.12))
                .overlay(shape.stroke(chosen ? Color.accentColor : Color.black.opacity(0.45), lineWidth: 1.2))
                .frame(width: Self.target.width, height: Self.target.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Self.describe(target))
        .accessibilityAddTraits(chosen ? .isSelected : [])
        .help(Self.describe(target))
        .position(Self.centre(of: target))
    }

    /// Corners are drawn flush with the little screen's corner, rounded only on the inside;
    /// edges as floating capsules.
    private static func shape(for target: IslandPlacement) -> UnevenRoundedRectangle {
        let r: CGFloat = 6
        guard target.isCorner else { return UnevenRoundedRectangle(cornerRadii: .init(topLeading: r, bottomLeading: r, bottomTrailing: r, topTrailing: r)) }
        let right = target.position == 1, bottom = target.edge == .bottom
        return UnevenRoundedRectangle(cornerRadii: .init(
            topLeading: bottom && right ? r : 0,
            bottomLeading: !bottom && right ? r : 0,
            bottomTrailing: !bottom && !right ? r : 0,
            topTrailing: bottom && !right ? r : 0
        ))
    }

    private static func centre(of target: IslandPlacement) -> CGPoint {
        let (w, h, t, gap) = (screen.width, screen.height, Self.target, inset)
        if target.isCorner {
            return CGPoint(x: target.position == 1 ? w - t.width / 2 : t.width / 2, y: target.edge == .bottom ? h - t.height / 2 : t.height / 2)
        }
        switch target.edge {
        case .top: return CGPoint(x: w * target.position, y: gap + t.height / 2)
        case .bottom: return CGPoint(x: w * target.position, y: h - gap - t.height / 2)
        case .left: return CGPoint(x: gap + t.width / 2, y: h * target.position)
        case .right: return CGPoint(x: w - gap - t.width / 2, y: h * target.position)
        }
    }

    static func describe(_ placement: IslandPlacement) -> String {
        if placement.isCorner {
            return "\(placement.edge == .bottom ? "Bottom" : "Top")-\(placement.position == 1 ? "right" : "left") corner"
        }
        let edge = placement.edge.rawValue.capitalized
        return placement.position == 0.5 ? "\(edge) edge, in the middle" : "Along the \(placement.edge.rawValue) edge"
    }
}
