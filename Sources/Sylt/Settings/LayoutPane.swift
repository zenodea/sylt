import SwiftUI

/// Decide what each closed wing shows. The island is drawn at the top with every item
/// in place; the list under each wing is that wing's content, in order. A tile's buttons
/// move it to the other wing or hide it, and dragging a tile onto another sets the order.
struct LayoutPane: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var plugins: PluginRegistry

    private var wingPlugins: [WingPlugin] { plugins.plugins.map(\.wingPlugin) }
    private var resolved: ResolvedWings { preferences.wingLayout.resolve(plugins: wingPlugins) }

    private var hidden: [WingItem] {
        let natural = WingLayout.natural(plugins: wingPlugins)
        let shown = Set(resolved.left + resolved.right)
        return (natural.left + natural.right).filter { !shown.contains($0) }
    }

    var body: some View {
        Section {
            VStack(spacing: 14) {
                IslandPreview(wings: resolved, describe: describe)
                HStack(alignment: .top, spacing: 14) {
                    wing(.left, items: resolved.left)
                    wing(.right, items: resolved.right)
                }
            }
            .padding(.vertical, 4)
        } header: {
            Text("Preview")
        }
        Section {
            if hidden.isEmpty {
                Text("Nothing hidden")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(hidden, id: \.id) { item in
                    HStack(spacing: 8) {
                        glyph(item)
                        Text(describe(item).title)
                        Spacer()
                        Button { move(item, to: .left) } label: { Label("Show on the left", systemImage: "arrow.left.to.line") }
                        Button { move(item, to: .right) } label: { Label("Show on the right", systemImage: "arrow.right.to.line") }
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                }
            }
            if preferences.wingLayout.isCustomised {
                HStack {
                    Spacer()
                    Button("Reset to defaults") { withAnimation(.snappy) { preferences.wingLayout = WingLayout() } }
                }
            }
        } header: {
            Text("Hidden")
        }
    }

    private func wing(_ column: WingColumn, items: [WingItem]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(column.title, systemImage: column == .left ? "arrow.up.left" : "arrow.up.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                ForEach(items, id: \.id) { item in
                    tile(item, in: column)
                        .draggable(item.id)
                        .dropDestination(for: String.self) { ids, _ in
                            ids.first.flatMap(WingItem.init(id:)).map { move($0, to: column, before: item) } ?? false
                        }
                }
                if items.isEmpty {
                    Text("Empty wing")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity, minHeight: 40)
                }
            }
            .padding(6)
            .frame(maxWidth: .infinity, alignment: .top)
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .dropDestination(for: String.self) { ids, _ in
                ids.first.flatMap(WingItem.init(id:)).map { move($0, to: column) } ?? false
            }
        }
    }

    private func tile(_ item: WingItem, in column: WingColumn) -> some View {
        HStack(spacing: 8) {
            glyph(item)
            Text(describe(item).title)
                .font(.callout)
                .lineLimit(1)
            Spacer(minLength: 4)
            Button {
                move(item, to: column == .left ? .right : .left)
            } label: {
                Label(column == .left ? "Move to the right wing" : "Move to the left wing", systemImage: column == .left ? "arrow.right" : "arrow.left")
            }
            Button { move(item, to: .hidden) } label: { Label("Hide", systemImage: "eye.slash") }
        }
        .labelStyle(.iconOnly)
        .buttonStyle(.borderless)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
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

    @discardableResult
    private func move(_ item: WingItem, to column: WingColumn, before target: WingItem? = nil) -> Bool {
        var layout = preferences.wingLayout
        layout.move(item, to: column, before: target, plugins: wingPlugins)
        withAnimation(.snappy) { preferences.wingLayout = layout }
        return true
    }

    /// Title and symbol for a tile and for the preview; plugins come from their manifests.
    private func describe(_ item: WingItem) -> (title: String, symbol: String, isExternal: Bool) {
        guard case .plugin(let id) = item, let plugin = plugins.plugins.first(where: { $0.id == id }) else {
            return (item.title, item.symbol, false)
        }
        return (plugin.manifest.name, plugin.manifest.symbol ?? item.symbol, !plugin.isBundled)
    }
}

/// The closed island with every placed item drawn as it looks when live, scaled down to
/// fit when the wings grow long. The notch is outlined so the two wings read as two.
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
            HStack(spacing: 12) { ForEach(wings.left, id: \.id) { sample($0) } }
                .padding(.leading, wings.left.isEmpty ? 0 : 14)
                .padding(.trailing, wings.left.isEmpty ? 0 : 8)
            UnevenRoundedRectangle(bottomLeadingRadius: 8, bottomTrailingRadius: 8, style: .continuous)
                .strokeBorder(.white.opacity(0.14), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                .frame(width: Self.notchWidth, height: Self.height - 8)
                .frame(height: Self.height, alignment: .top)
            HStack(spacing: 12) { ForEach(wings.right, id: \.id) { sample($0) } }
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
