import SwiftUI

struct ExpandedView: View {
    let notchHeight: CGFloat
    let layout: IslandLayout
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var plugins: PluginRegistry

    var body: some View {
        VStack(alignment: .leading, spacing: IslandLayout.sectionGap) {
            Spacer().frame(height: notchHeight - 8)
            if nowPlaying.track != nil {
                MediaCard(nowPlaying: nowPlaying).modifier(Staggered(index: 0))
            }
            if layout.showsNextEvent, let event = calendar.next {
                EventRow(event: event).modifier(Staggered(index: 1))
            }
            ForEach(plugins.plugins.filter { $0.isRunning && $0.section != nil }) { plugin in
                PluginSectionView(plugin: plugin).modifier(Staggered(index: 2))
            }
            if layout.expandedSections.isEmpty {
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
