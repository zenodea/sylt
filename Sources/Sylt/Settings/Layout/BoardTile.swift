import SwiftUI

struct TileDescription {
    let title: String
    let symbol: String
    var isExternal = false
}

/// A board's row for one item: its glyph and name, then whatever goes at the trailing end.
struct BoardTile<Trailing: View>: View {
    let description: TileDescription
    var foreground: HierarchicalShapeStyle = .primary
    @ViewBuilder let trailing: Trailing

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: description.symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(description.isExternal ? Color.purple : .accentColor, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            Text(description.title)
                .font(.callout)
                .lineLimit(1)
            Spacer(minLength: 4)
            trailing
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, 8)
        .frame(height: DragBoard.tileHeight)
        .background(.background, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.quaternary, lineWidth: 1))
        .contentShape(Rectangle())
    }
}

/// The room that opens where a dragged tile would land.
struct DropSlot: View {
    let open: Bool

    var body: some View {
        Color.clear.frame(height: open ? DragBoard.tileHeight + 4 : 0)
    }
}

/// One column of a board: its rows, the slot after the last one, and a word when it is empty.
struct BoardColumn<Item: Hashable, Row: View>: View {
    let key: String
    @ObservedObject var board: DragBoard
    let items: [Item]
    let placeholder: String
    @ViewBuilder let row: (Int, Item) -> Row

    var body: some View {
        let gap = board.gap(in: key)
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element) { index, item in
                row(index, item)
            }
            DropSlot(open: gap == items.count)
            if items.isEmpty, gap == nil {
                Text(placeholder)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, minHeight: 40)
            }
        }
        .animation(.snappy(duration: 0.25), value: board.drop)
        .padding(6)
    }
}
