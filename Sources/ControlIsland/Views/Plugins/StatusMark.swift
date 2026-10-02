import SwiftUI

/// A plugin item's status: green and breathing while working, blue and still
/// when done, amber and still while waiting.
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
