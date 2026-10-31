import SwiftUI

struct StatusMark: View {
    let status: PluginStatus
    var size: CGFloat = 6

    var body: some View {
        switch status {
        case .done: Circle().fill(Color.blue).frame(width: size, height: size)
        case .working, .waiting: StatusDot(working: status == .working, size: size)
        }
    }
}
