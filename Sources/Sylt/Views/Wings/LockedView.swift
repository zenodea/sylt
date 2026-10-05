import SwiftUI

/// The island at the lock screen: a padlock and the time, both hugging the
/// notch. On unlock the same view widens, the padlock springs open and the
/// time gives way to a greeting.
struct LockedView: View {
    let layout: IslandLayout
    let unlocked: Bool

    static let greeting = "Welcome back, \(NSFullUserName().split(separator: " ").first.map(String.init) ?? NSUserName())"
    static let leadingWing = HUDKind.wing(13)
    /// Fits the widest clock this locale can show; the island only widens on unlock.
    static let timeWing: CGFloat = {
        let twelveHour = Date().formatted(.dateTime.hour().minute()).rangeOfCharacter(from: .letters) != nil
        return HUDKind.wing(TextWidth.of(twelveHour ? "88:88 PM" : "88:88", size: 12))
    }()
    static let greetingWing = HUDKind.wing(TextWidth.of(greeting, size: 11))

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
                .frame(width: trailingWing - gap, alignment: .leading)
                .padding(.leading, gap)
        }
        .frame(height: layout.notchHeight + IslandLayout.notchOverlap)
    }

    private var trailingWing: CGFloat {
        unlocked ? Self.greetingWing : Self.timeWing
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
