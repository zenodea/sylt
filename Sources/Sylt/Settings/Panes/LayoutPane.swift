import SwiftUI

/// Decide what the island shows: the closed wings and the pages of the expanded view.
/// Tiles are dragged straight between lists; the others slide apart to make room.
struct LayoutPane: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var plugins: PluginRegistry
    @StateObject private var wingBoard = DragBoard()
    @StateObject private var pageBoard = DragBoard()
    @State private var editingGap: String?

    private static let wingSpace = "wings"
    private static let pageSpace = "pages"

    private var wingPlugins: [WingPlugin] { plugins.plugins.map(\.wingPlugin) }
    private var resolved: ResolvedWings { preferences.wingLayout.resolve(plugins: wingPlugins) }

    private var hidden: [WingItem] {
        let natural = WingLayout.natural(plugins: wingPlugins)
        let shown = Set(resolved.left + resolved.right)
        return (natural.left + natural.right).filter { !shown.contains($0) }
    }

    private var wingColumns: [(WingColumn, [WingItem])] {
        [(.left, resolved.left), (.right, resolved.right), (.hidden, hidden)]
    }

    private var wingIDs: [String: [String]] {
        Dictionary(uniqueKeysWithValues: wingColumns.map { ($0.0.rawValue, $0.1.map(\.id)) })
    }

    private var allSections: [ExpandedSection] {
        [.media, .event] + plugins.plugins.map { ExpandedSection.plugin($0.id) }
    }

    private var pages: [[ExpandedSection]] { preferences.expandedLayout.resolve(available: allSections) }

    private var pageIDs: [String: [String]] {
        var ids = Dictionary(uniqueKeysWithValues: pages.enumerated().map { (Self.pageKey($0.offset), $0.element.map(\.id)) })
        ids[Self.pageKey(nil)] = []
        return ids
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsCard(title: "Preview") {
                    IslandPreview(wings: resolved) { describe($0).symbol }
                }
                SettingsCard(title: "Wings") {
                    wingsBoard
                }
                SettingsCard(title: "Expanded view") {
                    pagesBoard
                }
                if preferences.wingLayout.isCustomised || preferences.expandedLayout.isCustomised {
                    HStack {
                        Spacer()
                        Button("Reset to defaults") {
                            preferences.wingLayout = WingLayout()
                            preferences.expandedLayout = ExpandedLayout()
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    // MARK: Wings

    private var wingsBoard: some View {
        HStack(alignment: .top, spacing: 14) {
            ForEach(wingColumns, id: \.0) { column, items in
                wingColumn(column, items: items)
            }
        }
        .coordinateSpace(name: Self.wingSpace)
        .onPreferenceChange(BoardFramesKey.self) { wingBoard.report($0) }
        .overlay(alignment: .topLeading) {
            if let id = wingBoard.dragging, let item = WingItem(id: id) {
                tile(item, in: nil).lifted(by: wingBoard)
            }
        }
    }

    private func wingColumn(_ column: WingColumn, items: [WingItem]) -> some View {
        let key = column.rawValue
        return VStack(alignment: .leading, spacing: 6) {
            Label(column.title, systemImage: column.symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            BoardColumn(key: key, board: wingBoard, items: items, placeholder: column == .hidden ? "Nothing hidden" : "Empty wing") { index, item in
                if index > 0, column != .hidden { gapHandle(between: items[index - 1], and: item) }
                DropSlot(open: wingBoard.gap(in: key) == index)
                tile(item, in: column)
                    .boardTile(item.id, on: wingBoard, space: Self.wingSpace, columns: wingIDs) { drop in
                        guard let target = WingColumn(rawValue: drop.column) else { return }
                        move(item, to: target, before: drop.before.flatMap(WingItem.init(id:)))
                    }
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .boardFrame("column:\(key)", space: Self.wingSpace)
        }
    }

    /// The space between two tiles: click it to set how far apart the two sit on the
    /// island, and whether a line divides them.
    private func gapHandle(between first: WingItem, and second: WingItem) -> some View {
        let key = WingLayout.gapKey(first, second)
        let gap = preferences.wingLayout.gap(between: first, and: second)
        let editing = editingGap == key
        return VStack(spacing: 4) {
            Button {
                withAnimation(.easeOut(duration: 0.18)) { editingGap = editing ? nil : key }
            } label: {
                HStack(spacing: 6) {
                    Rectangle().fill(.quaternary).frame(height: 1)
                    Text(gap.separator ? "\(Int(gap.spacing)) pt, line" : "\(Int(gap.spacing)) pt")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(editing ? Color.accentColor : .secondary)
                    Rectangle().fill(.quaternary).frame(height: 1)
                }
                .frame(height: 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if editing {
                HStack(spacing: 10) {
                    Slider(value: Binding(
                        get: { gap.spacing },
                        set: { setGap(WingGap(spacing: $0, separator: gap.separator), between: first, and: second) }
                    ), in: 2...32, step: 2)
                    Toggle("Line", isOn: Binding(
                        get: { gap.separator },
                        set: { setGap(WingGap(spacing: gap.spacing, separator: $0), between: first, and: second) }
                    ))
                    .toggleStyle(.checkbox)
                    .font(.caption)
                }
                .padding(.horizontal, 6)
                .padding(.bottom, 4)
            }
        }
    }

    private func setGap(_ gap: WingGap, between first: WingItem, and second: WingItem) {
        var layout = preferences.wingLayout
        layout.setGap(gap, between: first, and: second)
        preferences.wingLayout = layout
    }

    /// A tile; `column` nil is the floating copy that follows the pointer.
    private func tile(_ item: WingItem, in column: WingColumn?) -> some View {
        BoardTile(description: describe(item), foreground: .secondary) {
            Group {
                if let column, column != .hidden {
                    Button {
                        move(item, to: column == .left ? .right : .left)
                    } label: {
                        Label(column == .left ? "Move to the right wing" : "Move to the left wing", systemImage: column == .left ? "arrow.right" : "arrow.left")
                    }
                    Button { move(item, to: .hidden) } label: { Label("Hide", systemImage: "eye.slash") }
                } else if column == .hidden {
                    Button { move(item, to: .left) } label: { Label("Show on the left", systemImage: "arrow.left.to.line") }
                    Button { move(item, to: .right) } label: { Label("Show on the right", systemImage: "arrow.right.to.line") }
                }
            }
            .labelStyle(.iconOnly)
            .buttonStyle(.borderless)
        }
    }

    private func move(_ item: WingItem, to column: WingColumn, before target: WingItem? = nil) {
        var layout = preferences.wingLayout
        layout.move(item, to: column, before: target, plugins: wingPlugins)
        withTransaction(.unanimated) { preferences.wingLayout = layout }
    }

    // MARK: Pages

    private var pagesBoard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, sections in
                    pageColumn(index, sections: sections)
                }
                pageColumn(nil, sections: [])
            }
            .padding(.vertical, 4)
        }
        .coordinateSpace(name: Self.pageSpace)
        .onPreferenceChange(BoardFramesKey.self) { pageBoard.report($0) }
        .overlay(alignment: .topLeading) {
            if let id = pageBoard.dragging, let section = ExpandedSection(id: id) {
                sectionTile(section).lifted(by: pageBoard)
            }
        }
    }

    /// `index` nil is the empty column after the last page, where a drop starts a new one.
    private func pageColumn(_ index: Int?, sections: [ExpandedSection]) -> some View {
        let key = Self.pageKey(index)
        let isNew = index == nil
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(index.map { "Page \($0 + 1)" } ?? "New page")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isNew ? .tertiary : .secondary)
                Spacer()
                if let index {
                    Button { movePage(index, by: -1) } label: { Image(systemName: "chevron.left") }
                        .disabled(index == 0)
                    Button { movePage(index, by: 1) } label: { Image(systemName: "chevron.right") }
                        .disabled(index >= pages.count - 1)
                }
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            BoardColumn(key: key, board: pageBoard, items: sections, placeholder: isNew ? "Drop here" : "Empty page") { index, section in
                DropSlot(open: pageBoard.gap(in: key) == index)
                sectionTile(section)
                    .boardTile(section.id, on: pageBoard, space: Self.pageSpace, columns: pageIDs) { drop in
                        var layout = preferences.expandedLayout
                        layout.move(section, toPage: Self.pageIndex(drop.column) ?? pages.count, before: drop.before.flatMap(ExpandedSection.init(id:)), all: allSections)
                        withTransaction(.unanimated) { preferences.expandedLayout = layout }
                    }
            }
            .frame(width: 200, alignment: .top)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(.quaternary.opacity(isNew ? 0 : 0.35))
            )
            .overlay {
                if isNew {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(.quaternary, style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                }
            }
            .boardFrame("column:\(key)", space: Self.pageSpace)
        }
    }

    private static func pageKey(_ index: Int?) -> String {
        index.map { "page:\($0)" } ?? "page:new"
    }

    private static func pageIndex(_ key: String) -> Int? {
        Int(key.dropFirst("page:".count))
    }

    private func movePage(_ index: Int, by delta: Int) {
        var layout = preferences.expandedLayout
        layout.movePage(index, by: delta, all: allSections)
        withAnimation(.snappy(duration: 0.25)) { preferences.expandedLayout = layout }
    }

    private func sectionTile(_ section: ExpandedSection) -> some View {
        BoardTile(description: describe(section)) {
            Image(systemName: "line.3.horizontal").font(.caption).foregroundStyle(.quaternary)
        }
    }

    // MARK: Descriptions

    private func describe(_ item: WingItem) -> TileDescription {
        guard case .plugin(let id) = item else { return TileDescription(title: item.title, symbol: item.symbol) }
        return describe(plugin: id, symbol: item.symbol)
    }

    private func describe(_ section: ExpandedSection) -> TileDescription {
        guard case .plugin(let id) = section else { return TileDescription(title: section.title, symbol: section.symbol) }
        return describe(plugin: id, symbol: section.symbol)
    }

    /// Plugins are named by their manifests.
    private func describe(plugin id: String, symbol: String) -> TileDescription {
        guard let plugin = plugins.plugins.first(where: { $0.id == id }) else { return TileDescription(title: id, symbol: symbol) }
        return TileDescription(title: plugin.manifest.name, symbol: plugin.manifest.symbol ?? symbol, isExternal: !plugin.isBundled)
    }
}

private extension WingColumn {
    var symbol: String {
        switch self {
        case .left: "arrow.up.left"
        case .right: "arrow.up.right"
        case .hidden: "eye.slash"
        }
    }
}
