import AppKit
import Combine

/// The last few things copied as text, for pasting again from the island.
@MainActor
final class ClipboardMonitor: ObservableObject {
    struct Item: Hashable, Identifiable {
        let id = UUID()
        let text: String
        let date: Date

        var preview: String {
            text.trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\n", with: " ")
        }
    }

    @Published private(set) var items: [Item] = []

    static let capacity = 8
    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")

    private var timer: Timer?
    private var changeCount = NSPasteboard.general.changeCount

    func start() {
        guard timer == nil else { return }
        timer = .scheduledTimer(withTimeInterval: 0.7, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        items = []
    }

    func copy(_ item: Item) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(item.text, forType: .string)
        changeCount = pasteboard.changeCount
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        let types = pasteboard.types ?? []
        guard !types.contains(Self.concealed), !types.contains(Self.transient),
              let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        items.removeAll { $0.text == text }
        items.insert(Item(text: text, date: .now), at: 0)
        items = Array(items.prefix(Self.capacity))
    }
}
