import AppKit
import SwiftUI

struct SourceBadge: View {
    let bundleIdentifier: String?
    var size: CGFloat = 18

    var body: some View {
        if let icon = AppIcons.icon(for: bundleIdentifier) {
            Image(nsImage: icon)
                .resizable()
                .frame(width: size, height: size)
                .padding(1.5)
                .background(.black, in: RoundedRectangle(cornerRadius: size * 0.3, style: .continuous))
        }
    }
}
