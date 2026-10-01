import SwiftUI
import UniformTypeIdentifiers

struct ShelfSection: View {
    @ObservedObject var shelf: ShelfMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label("Shelf", systemImage: "tray.full.fill")
                Spacer()
                Button("Clear") { shelf.clear() }.buttonStyle(.plain).foregroundStyle(.white.opacity(0.5))
            }
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.white.opacity(0.5))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(shelf.files, id: \.self) { url in
                        VStack(spacing: 2) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
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
                            Button("Remove") { shelf.remove(url) }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
            }
            .animation(IslandAnimation.value, value: shelf.files)
        }
        .frame(height: IslandLayout.shelfHeight)
    }
}
