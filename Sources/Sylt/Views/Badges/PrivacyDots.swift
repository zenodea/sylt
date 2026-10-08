import SwiftUI

struct PrivacyDots: View {
    let use: PrivacyMonitor.Use

    var body: some View {
        HStack(spacing: 3) {
            if use.microphone { GlowDot(color: .orange).transition(.scale.combined(with: .opacity)) }
            if use.camera { GlowDot(color: .green).transition(.scale.combined(with: .opacity)) }
        }
    }
}
