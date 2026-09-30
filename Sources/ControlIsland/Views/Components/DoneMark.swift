import SwiftUI

/// A green tick that pops in once the HUD has opened.
struct DoneMark: View {
    @State private var shown = false

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.green)
            .scaleEffect(shown ? 1 : 0.4)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(IslandAnimation.unlock.delay(0.25)) { shown = true } }
    }
}
