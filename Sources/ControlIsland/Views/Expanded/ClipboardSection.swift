import SwiftUI

struct ClipboardSection: View {
    @ObservedObject var clipboard: ClipboardMonitor

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label("Clipboard", systemImage: "doc.on.clipboard.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.5))
            VStack(spacing: 3) {
                ForEach(clipboard.items.prefix(IslandLayout.maxClipboardRows)) { item in
                    Button {
                        clipboard.copy(item)
                        Haptics.press()
                    } label: {
                        HStack {
                            Text(item.preview).lineLimit(1)
                            Spacer()
                            Image(systemName: "doc.on.doc").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                        }
                        .padding(.horizontal, 8)
                        .frame(height: IslandLayout.clipboardRowHeight - 3)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}
