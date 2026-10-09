import SwiftUI

/// Each wing keeps its closed content unless the HUD claims that side, so a one-sided
/// HUD leaves the other wing untouched; a two-row HUD keeps both and adds a row underneath.
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
            .frame(height: layout.notchHeight + layout.overlap)
            if mode == .hud(.nowPlaying) {
                TrackRow().transition(IslandAnimation.content)
            }
            if case .hud(.notification(let notification)) = mode {
                NotificationRow(notification: notification).transition(IslandAnimation.content)
            }
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
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
        guard case .hud(let kind) = mode else { return nil }
        if case .notification = kind { return side == .leading ? kind : nil }
        guard case .compact(let leading, let trailing) = kind.style else { return nil }
        return (side == .leading ? leading : trailing) == nil ? nil : kind
    }
}
