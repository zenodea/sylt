import SwiftUI

/// The island at the lock screen: a padlock and the time. On unlock the same
/// view widens, the padlock springs open and the time gives way to a greeting.
struct LockedView: View {
    let layout: IslandLayout
    let unlocked: Bool

    var body: some View {
        HStack(spacing: 0) {
            LockGlyph(open: unlocked)
                .padding(.leading, 10)
                .frame(width: IslandLayout.lockWings.leading, alignment: .leading)
            Spacer().frame(width: layout.notchWidth)
            trailing
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .padding(.trailing, 10)
                .frame(width: trailingWidth, alignment: .trailing)
        }
        .frame(height: layout.notchHeight + 2)
    }

    private var trailingWidth: CGFloat {
        guard unlocked, case .compact(_, let trailing) = HUDKind.unlocked.style else { return IslandLayout.lockWings.trailing }
        return trailing
    }

    @ViewBuilder
    private var trailing: some View {
        if unlocked {
            Text("Welcome back, \(NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName())")
                .lineLimit(1)
                .transition(.blurReplace)
        } else {
            TimelineView(.everyMinute) { context in
                Text(context.date, format: .dateTime.hour().minute()).monospacedDigit()
            }
            .transition(.blurReplace)
        }
    }
}
