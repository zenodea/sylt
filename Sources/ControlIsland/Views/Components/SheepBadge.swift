import SwiftUI

struct SheepBadge: View {
    let workingCount: Int

    var body: some View {
        HStack(spacing: 4) {
            Text("🐑")
                .font(.system(size: 13))
                .opacity(workingCount > 0 ? 1 : 0.45)
            Text("\(workingCount)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .monospacedDigit()
        }
    }
}
