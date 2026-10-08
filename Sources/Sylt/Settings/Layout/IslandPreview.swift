import SwiftUI

/// The closed island as the wing layout would show it, scaled down to fit when it must.
struct IslandPreview: View {
    let wings: ResolvedWings
    let symbol: (WingItem) -> String
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
        let label = Font.badge
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
            pluginSample(id, symbol: symbol(item), font: label)
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
