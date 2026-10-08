import SwiftUI

struct StatusMark: View {
    let status: String
    var size: CGFloat = 6

    var body: some View {
        switch status {
        case "done": Circle().fill(Color.blue).frame(width: size, height: size)
        default: StatusDot(working: status == "working", size: size)
        }
    }
}
