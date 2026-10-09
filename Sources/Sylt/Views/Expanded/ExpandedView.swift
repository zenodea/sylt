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

    /// The page's spare height goes to its lists: each gets what its hidden rows need,
    /// shared evenly when there isn't enough for all. Anything left stays at the bottom.
    private var page: some View {
        VStack(alignment: .leading, spacing: IslandLayout.sectionGap) {
            let sections = layout.currentPageSections
            let extras = spareHeight(for: sections)
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                view(for: section, extra: extras[section.id] ?? 0).modifier(Staggered(index: index))
            }
            Spacer(minLength: 0)
            if sections.isEmpty {
                Text("Nothing playing")
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(maxWidth: .infinity)
                    .frame(height: IslandLayout.emptyExpandedHeight)
            }
        }
    }

    private func spareHeight(for sections: [ExpandedSection]) -> [String: CGFloat] {
        var wants: [(id: String, need: CGFloat)] = []
        for section in sections {
            guard case .plugin(let id) = section, let need = plugins.plugin(id)?.section?.hiddenRowsHeight, need > 0 else { continue }
            wants.append((section.id, need))
        }
        guard !wants.isEmpty else { return [:] }
        let used = sections.map(layout.height(of:)).reduce(0, +) + CGFloat(max(0, sections.count - 1)) * IslandLayout.sectionGap
        let dots: CGFloat = layout.expandedPages.count > 1 ? IslandLayout.pageDotsHeight : 0
        var spare = max(0, layout.expandedHeight - IslandLayout.expandedBaseHeight - dots - used)
        var granted: [String: CGFloat] = [:]
        // Water-filling: the smallest need is met first, the rest share what remains.
        var open = wants.sorted { $0.need < $1.need }
        while !open.isEmpty, spare > 0 {
            let share = spare / CGFloat(open.count)
            let first = open.removeFirst()
            let given = min(first.need, share)
            granted[first.id] = given
            spare -= given
        }
        return granted
    }

    @ViewBuilder
    private func view(for section: ExpandedSection, extra: CGFloat) -> some View {
        switch section {
        case .media:
            MediaCard(nowPlaying: nowPlaying)
        case .event:
            if let event = calendar.next { EventRow(event: event) }
        case .plugin(let id):
            if let plugin = plugins.plugin(id) { PluginSectionView(plugin: plugin, extraHeight: extra) }
        }
    }
}

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
