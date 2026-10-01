import SwiftUI

struct PrivacyDots: View {
    let use: PrivacyMonitor.Use

    var body: some View {
        HStack(spacing: 3) {
            if use.microphone { dot(.orange) }
            if use.camera { dot(.green) }
        }
    }

    private func dot(_ color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 7, height: 7)
            .shadow(color: color.opacity(0.8), radius: 3)
            .transition(.scale.combined(with: .opacity))
    }
}
