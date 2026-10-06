import SwiftUI

/// The open island: one page of sections at a time, turned with a sideways swipe.
struct ExpandedView: View {
    let notchHeight: CGFloat
    let layout: IslandLayout
    var pageDirection = 1
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var calendar: CalendarMonitor
    @EnvironmentObject private var plugins: PluginRegistry

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer().frame(height: notchHeight + 6)
            page
                .frame(maxHeight: .infinity)
                .id(layout.expandedPage)
                .transition(.asymmetric(
                    insertion: .move(edge: pageDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: pageDirection > 0 ? .leading : .trailing).combined(with: .opacity)
                ))
            if layout.expandedPages.count > 1 {
                PageDots(count: layout.expandedPages.count, current: layout.expandedPage)
                    .frame(height: IslandLayout.pageDotsHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .padding(.horizontal, 14)
        .padding(.bottom, 12)
        .clipped()
    }

    /// Lists grow to take whatever height the page has; a page with no list keeps its
    /// sections at the top.
    private var page: some View {
        VStack(alignment: .leading, spacing: IslandLayout.sectionGap) {
            let sections = layout.currentPageSections
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                view(for: section).modifier(Staggered(index: index))
            }
            if !sections.contains(where: hasList) { Spacer(minLength: 0) }
            if sections.isEmpty {
                Text("Nothing playing")
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: IslandLayout.emptyExpandedHeight)
            }
        }
    }

    private func hasList(_ section: ExpandedSection) -> Bool {
        guard case .plugin(let id) = section else { return false }
        return plugins.plugins.first { $0.id == id }?.section?.rows?.isEmpty == false
    }

    @ViewBuilder
    private func view(for section: ExpandedSection) -> some View {
        switch section {
        case .media:
            MediaCard(nowPlaying: nowPlaying)
        case .event:
            if let event = calendar.next { EventRow(event: event) }
        case .plugin(let id):
            if let plugin = plugins.plugins.first(where: { $0.id == id }) { PluginSectionView(plugin: plugin) }
        }
    }
}

/// Which page is open, as the dots every pager uses.
private struct PageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == current ? 0.9 : 0.3))
                    .frame(width: index == current ? 12 : 5, height: 5)
                    .animation(IslandAnimation.value, value: current)
            }
        }
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
