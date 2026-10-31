import SwiftUI

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
            spread
                .frame(maxHeight: .infinity)
                .id(layout.currentSpread)
                .transition(.asymmetric(
                    insertion: .move(edge: pageDirection > 0 ? .trailing : .leading).combined(with: .opacity),
                    removal: .move(edge: pageDirection > 0 ? .leading : .trailing).combined(with: .opacity)
                ))
            if layout.spreadCount > 1 {
                PageDots(count: layout.spreadCount, current: layout.currentSpread)
                    .frame(height: IslandLayout.pageDotsHeight)
                    .frame(maxWidth: .infinity)
            }
        }
        .font(.system(size: 12, weight: .medium, design: .rounded))
        .foregroundStyle(.white)
        .padding(.bottom, 12)
        .clipped()
    }

    private var spread: some View {
        HStack(alignment: .top, spacing: 0) {
            let pages = layout.currentSpreadPages
            ForEach(Array(pages.enumerated()), id: \.offset) { index, sections in
                if index > 0 {
                    Rectangle().fill(.white.opacity(0.1)).frame(width: 1).padding(.vertical, 4)
                }
                page(sections)
                    .padding(.horizontal, 14)
                    .frame(width: IslandLayout.expandedWidth - (index > 0 ? 1 : 0))
            }
            if pages.count < layout.columns { Spacer(minLength: 0) }
        }
        .frame(width: layout.expandedWidth)
    }

    private func page(_ sections: [ExpandedSection]) -> some View {
        VStack(alignment: .leading, spacing: IslandLayout.sectionGap) {
            let extras = listExtras(for: sections)
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

    private func listExtras(for sections: [ExpandedSection]) -> [String: CGFloat] {
        var needs: [String: CGFloat] = [:]
        for section in sections {
            guard case .plugin(let id) = section, let need = plugins.plugin(id)?.section?.hiddenRowsHeight else { continue }
            needs[section.id] = need
        }
        return IslandLayout.share(layout.spareHeight(on: sections), among: needs)
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
