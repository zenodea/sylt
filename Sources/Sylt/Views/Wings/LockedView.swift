import SwiftUI

/// The island at the lock screen: a padlock and the time, both hugging the notch. On
/// unlock the same view widens, the padlock springs open and the time gives way to a greeting.
struct LockedView: View {
    let layout: IslandLayout
    let unlocked: Bool
    /// Locking shows the padlock open for an instant and closes it, the unlock in reverse.
    @State private var closing = false

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
            if layout.lockShowsStatus, !unlocked {
                ClosedWing(side: .leading, layout: layout).padding(.horizontal, IslandLayout.wingPadding)
            }
            LockGlyph(open: unlocked || closing)
                .frame(width: Self.leadingWing - gap, alignment: .trailing)
                .padding(.trailing, gap)
            Spacer().frame(width: layout.notchWidth)
            trailing
                .font(.system(size: unlocked ? 11 : 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: (unlocked ? Self.greetingWing : Self.timeWing) - gap, alignment: .leading)
                .padding(.leading, gap)
            if layout.lockShowsStatus, !unlocked {
                ClosedWing(side: .trailing, layout: layout).padding(.horizontal, IslandLayout.wingPadding)
            }
        }
        .frame(height: layout.notchHeight + layout.overlap)
        .task {
            guard !unlocked else { return }
            closing = true
            try? await Task.sleep(for: .seconds(0.2))
            withAnimation(IslandAnimation.unlock) { closing = false }
        }
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
