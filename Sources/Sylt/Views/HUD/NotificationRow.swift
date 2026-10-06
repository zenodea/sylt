import SwiftUI

/// Title and body under the notch while a notification shows, where a track's title goes.
struct NotificationRow: View {
    let notification: SystemNotification

    var body: some View {
        MarqueeText(text: notification.body.isEmpty ? notification.title : "\(notification.title)  ·  \(notification.body)")
            .foregroundStyle(.white.opacity(0.85))
            .frame(height: IslandLayout.hudRowHeight)
            .padding(.horizontal, 12)
            .padding(.bottom, 4)
    }
}
