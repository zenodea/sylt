import SwiftUI

struct NotificationRow: View {
    let notification: SystemNotification

    var body: some View {
        HUDRow(title: notification.title, detail: notification.body)
    }
}
