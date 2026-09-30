import SwiftUI

/// The island at the lock screen: a padlock and the time, both hugging the
/// notch. On unlock the same view widens, the padlock springs open and the
/// time gives way to a greeting.
struct LockedView: View {
    let layout: IslandLayout
    let unlocked: Bool

    static let greeting = "Welcome back, \(NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName())"
    static let leadingWing = HUDKind.wing(13)

    var body: some View {
        let gap = IslandLayout.notchGap
        HStack(spacing: 0) {
            LockGlyph(open: unlocked)
                .frame(width: Self.leadingWing - gap, alignment: .trailing)
                .padding(.trailing, gap)
            Spacer().frame(width: layout.notchWidth)
            trailing
                .font(.system(size: unlocked ? 11 : 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: IslandLayout.hudWings - Self.leadingWing - gap, alignment: .leading)
                .padding(.leading, gap)
        }
        .frame(height: layout.notchHeight + 2)
    }

    @ViewBuilder
    private var trailing: some View {
        if unlocked {
            Text(Self.greeting)
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
