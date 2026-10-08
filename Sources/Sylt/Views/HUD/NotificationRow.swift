import SwiftUI

struct NotificationRow: View {
    let notification: SystemNotification

    var body: some View {
        HUDRow(text: notification.body.isEmpty ? notification.title : "\(notification.title)  ·  \(notification.body)")
    }
}
