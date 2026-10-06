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
    private static let tileHeight: CGFloat = 32

    private var wingPlugins: [WingPlugin] { plugins.plugins.map(\.wingPlugin) }
    private var resolved: ResolvedWings { preferences.wingLayout.resolve(plugins: wingPlugins) }

    private var hidden: [WingItem] {
        let natural = WingLayout.natural(plugins: wingPlugins)
        let shown = Set(resolved.left + resolved.right)
        return (natural.left + natural.right).filter { !shown.contains($0) }
    }

    private var allSections: [ExpandedSection] {
        [.media, .event] + plugins.plugins.map { ExpandedSection.plugin($0.id) }
    }

    private var resolvedPages: [[ExpandedSection]] { preferences.expandedLayout.resolve(available: allSections) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                SettingsCard(title: "Preview") {
                    IslandPreview(wings: resolved, describe: describe)
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
        let columns: [(WingColumn, [WingItem])] = [(.left, resolved.left), (.right, resolved.right), (.hidden, hidden)]
        wingBoard.columns = Dictionary(uniqueKeysWithValues: columns.map { ($0.0.rawValue, $0.1.map(\.id)) })
        return HStack(alignment: .top, spacing: 14) {
            ForEach(columns, id: \.0) { column, items in
                wingColumn(column, items: items)
            }
        }
        .coordinateSpace(name: Self.wingSpace)
        .onPreferenceChange(BoardFramesKey.self) { wingBoard.report($0) }
        .overlay(alignment: .topLeading) {
            if let id = wingBoard.dragging, let item = WingItem(id: id) {
                let frame = wingBoard.liftFrame
                tile(item, in: nil)
                    .frame(width: frame.width)
                    .scaleEffect(1.03)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    .offset(x: frame.minX + wingBoard.translation.width, y: frame.minY + wingBoard.translation.height)
                    .allowsHitTesting(false)
            }
        }
    }

    private func wingColumn(_ column: WingColumn, items: [WingItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(column.title, systemImage: column == .left ? "arrow.up.left" : column == .right ? "arrow.up.right" : "eye.slash")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                let gap = wingBoard.gap(in: column.rawValue)
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0, column != .hidden { gapHandle(between: items[index - 1], and: item) }
                    slot(open: gap == index)
                    tile(item, in: column)
                        .boardFrame("tile:\(item.id)", space: Self.wingSpace)
                        .opacity(wingBoard.dragging == item.id ? 0 : 1)
                        .frame(height: wingBoard.dragging == item.id ? 0 : nil)
                        .clipped()
                        .gesture(wingDrag(item))
                }
                slot(open: gap == items.count)
                if items.isEmpty, gap == nil {
                    Text(column == .hidden ? "Nothing hidden" : "Empty wing")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .animation(.snappy(duration: 0.25), value: wingBoard.drop)
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .boardFrame("column:\(column.rawValue)", space: Self.wingSpace)
        }
    }

    private func wingDrag(_ item: WingItem) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.wingSpace))
            .onChanged { value in wingBoard.update(item.id, location: value.location, translation: value.translation) }
            .onEnded { _ in
                guard let result = wingBoard.end(), let column = WingColumn(rawValue: result.column) else { return }
                move(item, to: column, before: result.before.flatMap(WingItem.init(id:)))
            }
    }

    /// The room that opens where a dragged tile would land.
    private func slot(open: Bool) -> some View {
        Color.clear.frame(height: open ? Self.tileHeight + 4 : 0)
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
        HStack(spacing: 8) {
            glyph(item)
            Text(describe(item).title)
                .font(.callout)
                .lineLimit(1)
            Spacer(minLength: 4)
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
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .frame(height: Self.tileHeight)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.quaternary, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func glyph(_ item: WingItem) -> some View {
        let description = describe(item)
        return Image(systemName: description.symbol)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 22, height: 22)
            .background(description.isExternal ? Color.purple : .accentColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private func move(_ item: WingItem, to column: WingColumn, before target: WingItem? = nil) {
        var layout = preferences.wingLayout
        layout.move(item, to: column, before: target, plugins: wingPlugins)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) { preferences.wingLayout = layout }
    }

    /// Title and symbol for a tile and for the preview; plugins come from their manifests.
    private func describe(_ item: WingItem) -> (title: String, symbol: String, isExternal: Bool) {
        guard case .plugin(let id) = item, let plugin = plugins.plugins.first(where: { $0.id == id }) else {
            return (item.title, item.symbol, false)
        }
        return (plugin.manifest.name, plugin.manifest.symbol ?? item.symbol, !plugin.isBundled)
    }

    // MARK: Pages

    private var pagesBoard: some View {
        let pages = resolvedPages
        var columns = Dictionary(uniqueKeysWithValues: pages.enumerated().map { ("page:\($0.offset)", $0.element.map(\.id)) })
        columns["page:new"] = []
        pageBoard.columns = columns
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .top, spacing: 12) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, sections in
                    pageColumn("page:\(index)", title: "Page \(index + 1)", sections: sections)
                }
                pageColumn("page:new", title: "New page", sections: [])
            }
            .padding(.vertical, 4)
        }
        .coordinateSpace(name: Self.pageSpace)
        .onPreferenceChange(BoardFramesKey.self) { pageBoard.report($0) }
        .overlay(alignment: .topLeading) {
            if let id = pageBoard.dragging, let section = ExpandedSection(id: id) {
                let frame = pageBoard.liftFrame
                sectionTile(section)
                    .frame(width: frame.width)
                    .scaleEffect(1.03)
                    .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
                    .offset(x: frame.minX + pageBoard.translation.width, y: frame.minY + pageBoard.translation.height)
                    .allowsHitTesting(false)
            }
        }
    }

    private func pageColumn(_ key: String, title: String, sections: [ExpandedSection]) -> some View {
        let isNew = key == "page:new"
        let index = Int(key.dropFirst(5)) ?? -1
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isNew ? .tertiary : .secondary)
                Spacer()
                if !isNew {
                    // The whole page moves earlier or later.
                    Button { movePage(index, by: -1) } label: { Image(systemName: "chevron.left") }
                        .disabled(index == 0)
                    Button { movePage(index, by: 1) } label: { Image(systemName: "chevron.right") }
                        .disabled(index >= resolvedPages.count - 1)
                }
            }
            .buttonStyle(.borderless)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                let gap = pageBoard.gap(in: key)
                ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                    slot(open: gap == index)
                    sectionTile(section)
                        .boardFrame("tile:\(section.id)", space: Self.pageSpace)
                        .opacity(pageBoard.dragging == section.id ? 0 : 1)
                        .frame(height: pageBoard.dragging == section.id ? 0 : nil)
                        .clipped()
                        .gesture(pageDrag(section))
                }
                slot(open: gap == sections.count)
                if sections.isEmpty, gap == nil {
                    Text(isNew ? "Drop here" : "Empty page")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .animation(.snappy(duration: 0.25), value: pageBoard.drop)
            .padding(6)
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

    private func pageDrag(_ section: ExpandedSection) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named(Self.pageSpace))
            .onChanged { value in pageBoard.update(section.id, location: value.location, translation: value.translation) }
            .onEnded { _ in
                guard let result = pageBoard.end() else { return }
                let index = result.column == "page:new" ? resolvedPages.count : Int(result.column.dropFirst(5)) ?? resolvedPages.count
                var layout = preferences.expandedLayout
                layout.move(section, toPage: index, before: result.before.flatMap(ExpandedSection.init(id:)), all: allSections)
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { preferences.expandedLayout = layout }
            }
    }

    private func movePage(_ index: Int, by delta: Int) {
        var layout = preferences.expandedLayout
        layout.movePage(index, by: delta, all: allSections)
        withAnimation(.snappy(duration: 0.25)) { preferences.expandedLayout = layout }
    }

    private func sectionTile(_ section: ExpandedSection) -> some View {
        let description = describeSection(section)
        return HStack(spacing: 8) {
            Image(systemName: description.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(description.isExternal ? Color.purple : .accentColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(description.title).font(.callout).lineLimit(1)
            Spacer(minLength: 4)
            Image(systemName: "line.3.horizontal").font(.caption).foregroundStyle(.quaternary)
        }
        .padding(.horizontal, 8)
        .frame(height: Self.tileHeight)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.quaternary, lineWidth: 1))
        .contentShape(Rectangle())
    }

    private func describeSection(_ section: ExpandedSection) -> (title: String, symbol: String, isExternal: Bool) {
        guard case .plugin(let id) = section, let plugin = plugins.plugins.first(where: { $0.id == id }) else {
            return (section.title, section.symbol, false)
        }
        return (plugin.manifest.name, plugin.manifest.symbol ?? section.symbol, !plugin.isBundled)
    }
}

private struct IslandPreview: View {
    let wings: ResolvedWings
    let describe: (WingItem) -> (title: String, symbol: String, isExternal: Bool)
    @State private var islandWidth: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    private static let notchWidth: CGFloat = 110
    private static let height: CGFloat = 36

    var body: some View {
        GeometryReader { geometry in
            let scale = islandWidth > 0 ? min(1, (geometry.size.width - 16) / islandWidth) : 1
            island
                .scaleEffect(scale, anchor: .top)
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .top)
        }
        .onPreferenceChange(IslandWidthKey.self) { islandWidth = $0 }
        .frame(height: Self.height + 30)
        .background(wallpaper, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    /// A desktop behind the island: deep blue at night, pale blue by day.
    private var wallpaper: LinearGradient {
        colorScheme == .dark
            ? LinearGradient(colors: [Color(red: 0.12, green: 0.17, blue: 0.32), Color(red: 0.06, green: 0.08, blue: 0.15)], startPoint: .top, endPoint: .bottom)
            : LinearGradient(colors: [Color(red: 0.86, green: 0.9, blue: 1), Color(red: 0.78, green: 0.83, blue: 0.96)], startPoint: .top, endPoint: .bottom)
    }

    private var island: some View {
        HStack(spacing: 0) {
            row(wings.left)
                .padding(.leading, wings.left.isEmpty ? 0 : 14)
                .padding(.trailing, wings.left.isEmpty ? 0 : 8)
            UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: Self.notchWidth, height: Self.height - 8)
                .frame(height: Self.height, alignment: .top)
            row(wings.right)
                .padding(.leading, wings.right.isEmpty ? 0 : 8)
                .padding(.trailing, wings.right.isEmpty ? 0 : 14)
        }
        .frame(height: Self.height)
        .background(.black, in: UnevenRoundedRectangle(bottomLeadingRadius: 14, bottomTrailingRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.45), radius: 10, y: 5)
        .fixedSize()
        .background(GeometryReader { proxy in Color.clear.preference(key: IslandWidthKey.self, value: proxy.size.width) })
        .animation(.snappy, value: wings)
    }

    private func row(_ items: [WingItem]) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 { WingGapView(gap: wings.gap(between: items[index - 1], and: item)) }
                sample(item)
            }
        }
    }

    @ViewBuilder
    private func sample(_ item: WingItem) -> some View {
        let label = Font.system(size: 11, weight: .semibold, design: .rounded)
        switch item {
        case .calendar:
            HStack(spacing: 4) { Image(systemName: "calendar"); Text("12m") }.font(label).foregroundStyle(.white)
        case .privacy:
            HStack(spacing: 3) {
                Circle().fill(.orange).frame(width: 7, height: 7)
                Circle().fill(.green).frame(width: 7, height: 7)
            }
        case .focus:
            Image(systemName: "moon.fill").font(label).foregroundStyle(.indigo)
        case .headphones:
            HStack(spacing: 4) { Image(systemName: "headphones"); Text("80%") }.font(label).foregroundStyle(.white)
        case .music:
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(LinearGradient(colors: [.pink, .orange], startPoint: .top, endPoint: .bottom))
                    .frame(width: 20, height: 20)
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach([6, 12, 8, 14], id: \.self) { height in Capsule().fill(.pink).frame(width: 3, height: CGFloat(height)) }
                }
            }
        case .plugin(let id):
            pluginSample(id, symbol: describe(item).symbol, font: label)
        }
    }

    /// Roughly what each shipped plugin puts in its wing; anything else is its glyph.
    @ViewBuilder
    private func pluginSample(_ id: String, symbol: String, font: Font) -> some View {
        switch id {
        case "agents":
            HStack(spacing: 5) {
                ForEach(0..<2, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(.white.opacity(0.18))
                        .frame(width: 16, height: 16)
                        .overlay(Image(systemName: "terminal.fill").font(.system(size: 8, weight: .bold)).foregroundStyle(.white))
                        .overlay(alignment: .bottomTrailing) {
                            Circle().fill(index == 0 ? .green : .orange).frame(width: 6, height: 6).offset(x: 2, y: 2)
                        }
                }
            }
        case "timer":
            HStack(spacing: 4) { Image(systemName: symbol); Text("12:00").monospacedDigit() }.font(font).foregroundStyle(.white)
        case "weather":
            HStack(spacing: 4) { Image(systemName: symbol).symbolRenderingMode(.multicolor); Text("21°") }.font(font).foregroundStyle(.white)
        case "downloads":
            Image(systemName: symbol).font(font).foregroundStyle(.white)
                .overlay(Circle().trim(from: 0, to: 0.7).stroke(.blue, lineWidth: 1.5).rotationEffect(.degrees(-90)).frame(width: 18, height: 18))
        default:
            Image(systemName: symbol).font(font).foregroundStyle(.white)
        }
    }
}

private struct IslandWidthKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
