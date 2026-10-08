import SwiftUI

struct WingGapView: View {
    let gap: WingGap

    var body: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: CGFloat(gap.spacing) / 2)
            if gap.separator {
                RoundedRectangle(cornerRadius: 0.5)
                    .fill(.white.opacity(0.28))
                    .frame(width: WingGap.separatorWidth, height: 12)
            }
            Spacer().frame(width: CGFloat(gap.spacing) / 2)
        }
    }
}
