import SwiftUI
import UniformTypeIdentifiers

/// A plugin's expanded section: an optional header with actions, rows, a strip of files, and buttons.
struct PluginSectionView: View {
    @ObservedObject var plugin: ExternalPlugin

    var body: some View {
        if let section = plugin.section {
            VStack(alignment: .leading, spacing: 4) {
                if let title = section.title {
                    HStack(spacing: 6) {
                        if let symbol = section.symbol { Image(systemName: symbol) }
                        Text(title)
                        Spacer()
                        if let items = section.items { PluginBadge(items: items) }
                        ForEach(section.actions ?? []) { action in
                            Button(action.title) { plugin.send(PluginEvent(event: "action", id: action.id)); Haptics.press() }
                                .buttonStyle(.plain)
                        }
                    }
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                    .frame(height: PluginSection.headerHeight - 4)
                }
                if let rows = section.rows, !rows.isEmpty {
                    // More rows than fit scroll inside the space the first few take.
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: 3) {
                            ForEach(rows) { row in
                                PluginRowView(row: row) { plugin.send(PluginEvent(event: "click", row: row.rowID)); Haptics.press() } button: { id in
                                    plugin.send(PluginEvent(event: "button", row: row.rowID, id: id)); Haptics.press()
                                }
                            }
                        }
                    }
                    .frame(height: rows.prefix(PluginSection.maxRows).reduce(0) { $0 + $1.height } - 3)
                }
                if let paths = section.files, !paths.isEmpty {
                    fileStrip(paths)
                }
                if let buttons = section.buttons, !buttons.isEmpty {
                    HStack(spacing: 8) {
                        if section.title == nil, let symbol = section.symbol {
                            Image(systemName: symbol).foregroundStyle(.white.opacity(0.6)).padding(.trailing, 2)
                        }
                        ForEach(buttons) { button in
                            Button(button.title) { plugin.send(PluginEvent(event: "button", id: button.id)); Haptics.expand() }
                                .buttonStyle(Pill(tint: .white.opacity(0.1)))
                        }
                    }
                    .frame(height: PluginSection.buttonsHeight - 4)
                }
            }
            .animation(IslandAnimation.value, value: section)
        }
    }

    private func fileStrip(_ paths: [String]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(paths, id: \.self) { path in
                    let url = URL(fileURLWithPath: path)
                    VStack(spacing: 2) {
                        Image(nsImage: NSWorkspace.shared.icon(forFile: path))
                            .resizable()
                            .frame(width: 28, height: 28)
                        Text(url.lastPathComponent)
                            .font(.system(size: 9))
                            .lineLimit(1)
                            .frame(width: 52)
                    }
                    .onDrag { NSItemProvider(contentsOf: url) ?? NSItemProvider() }
                    .onTapGesture { NSWorkspace.shared.open(url) }
                    .contextMenu {
                        Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) }
                        Button("Remove") { plugin.send(PluginEvent(event: "remove", row: path)) }
                    }
                }
            }
        }
        .frame(height: PluginSection.filesHeight - 4)
    }
}

private struct PluginRowView: View {
    let row: PluginRow
    let tap: () -> Void
    let button: (String) -> Void

    var body: some View {
        Button(action: tap) {
            HStack(spacing: 8) {
                if row.symbol != nil || row.image != nil {
                    PluginGlyph(symbol: row.symbol, image: row.image, size: row.large == true ? 20 : 16)
                }
                VStack(alignment: .leading, spacing: 0) {
                    if let title = row.title {
                        Text(title)
                            .font(row.large == true ? .system(size: 15, weight: .semibold, design: .rounded) : .system(size: 12, weight: .medium, design: .rounded))
                            .lineLimit(1)
                    }
                    if let detail = row.detail {
                        Text(detail).font(.system(size: 10)).foregroundStyle(.white.opacity(0.5)).lineLimit(1)
                    }
                }
                Spacer()
                if let progress = row.progress {
                    LevelBar(value: progress).frame(width: 60)
                }
                if let trailing = row.trailing {
                    Text(trailing)
                        .font(.system(size: 11))
                        .foregroundStyle(Color(tint: row.trailingTint ?? "dim"))
                        .monospacedDigit()
                }
                if let status = row.status {
                    if status == "working" { WorkingDots() } else { StatusMark(status: status) }
                }
                ForEach(row.buttons ?? []) { item in
                    Button(item.title) { button(item.id) }.buttonStyle(Pill(tint: .white.opacity(0.12)))
                }
            }
            .padding(.vertical, 3)
            .padding(.horizontal, 8)
            .frame(height: row.height - 3)
            .background(.white.opacity(row.highlighted == true ? 0.12 : 0.06), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
