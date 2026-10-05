import SwiftUI

/// The island's two wings. Each keeps its closed content unless the current
/// HUD claims that side, so a one-sided HUD leaves the other wing untouched.
/// A track change keeps both wings and adds the title row underneath.
struct WingsView: View {
    let mode: IslandMode
    let layout: IslandLayout

    var body: some View {
        let widths = layout.wingWidths(for: mode)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                wing(.leading, width: widths.leading)
                Spacer().frame(width: layout.notchWidth)
                wing(.trailing, width: widths.trailing)
            }
            .frame(height: wingsHeight)
            if mode == .hud(.nowPlaying) {
                TrackRow().transition(IslandAnimation.content)
            }
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
    }

    private var wingsHeight: CGFloat {
        layout.notchHeight + IslandLayout.notchOverlap
    }

    /// Content hugs the notch; the slack sits at the island's outer end.
    private func wing(_ side: HUDWing.Side, width: CGFloat) -> some View {
        Group {
            if let kind = hudKind(claiming: side) {
                HUDWing(kind: kind, side: side, layout: layout)
                    .padding(side == .leading ? .trailing : .leading, IslandLayout.notchGap)
                    .id(kind.wingIdentity)
            } else {
                ClosedWing(side: side, layout: layout)
                    .padding(.horizontal, IslandLayout.wingPadding)
            }
        }
        .transition(IslandAnimation.content)
        .frame(width: width, alignment: side == .leading ? .trailing : .leading)
    }

    private func hudKind(claiming side: HUDWing.Side) -> HUDKind? {
        guard case .hud(let kind) = mode, case .compact(let leading, let trailing) = kind.style else { return nil }
        return (side == .leading ? leading : trailing) == nil ? nil : kind
    }
}
