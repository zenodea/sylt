import SwiftUI

struct StatusDot: View {
    let active: Bool

    var body: some View {
        Circle()
            .fill(active ? Color.green : Color.gray)
            .frame(width: 7, height: 7)
    }
}
