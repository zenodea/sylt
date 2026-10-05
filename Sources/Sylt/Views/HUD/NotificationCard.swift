import SwiftUI

/// The notification card: the one HUD that replaces the wings outright.
struct NotificationCard: View {
    let notification: SystemNotification
    let layout: IslandLayout

    var body: some View {
        VStack(spacing: 6) {
            Spacer().frame(height: layout.notchHeight - 4)
            Group {
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
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
    }
}
