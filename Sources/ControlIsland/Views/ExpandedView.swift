import SwiftUI

struct ExpandedView: View {
    let notchHeight: CGFloat
    @EnvironmentObject private var herdr: HerdrMonitor
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer().frame(height: notchHeight - 8)
            if nowPlaying.track != nil {
                MediaCard(nowPlaying: nowPlaying)
                    .modifier(Staggered(index: 0))
            }
            if herdr.available {
                HerdrSection(herdr: herdr)
                    .modifier(Staggered(index: 1))
            }
            if nowPlaying.track == nil, !herdr.available {
                Text("Nothing playing")
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: IslandLayout.emptyExpandedHeight)
            }
            Spacer(minLength: 0)
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
    }
}

private struct Staggered: ViewModifier {
    let index: Int
    @State private var shown = false

    func body(content: Content) -> some View {
        content
            .opacity(shown ? 1 : 0)
            .offset(y: shown ? 0 : -6)
            .onAppear { withAnimation(IslandAnimation.stagger(index)) { shown = true } }
    }
}
