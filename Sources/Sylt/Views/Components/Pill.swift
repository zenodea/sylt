import SwiftUI

struct Pill: ButtonStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(tint, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.94 : 1)
            .animation(IslandAnimation.press, value: configuration.isPressed)
    }
}
