import SwiftUI

/// The notification card: the one HUD that replaces the wings outright.
struct HUDView: View {
    let kind: HUDKind
    let layout: IslandLayout

    var body: some View {
        Group {
            switch kind.style {
            case .compact, .twoRow: EmptyView()
            case .card: card
            }
        }
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
    }

    @ViewBuilder
    private var card: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: layout.notchHeight - 4)
            if case .notification(let notification) = kind {
                HStack(spacing: 10) {
                    if let icon = notification.icon {
                        Image(nsImage: icon).resizable().frame(width: 28, height: 28)
                    } else {
                        Image(systemName: "bell.fill").frame(width: 28, height: 28)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(notification.title).lineLimit(1)
                        Text(notification.body).lineLimit(1)
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer(minLength: 0)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}
