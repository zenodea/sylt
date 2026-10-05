import AppKit
import Combine

/// Watches the pasteboard for plugins that ask, skipping concealed and transient
/// content such as password managers, and hands them the text.
@MainActor
final class ClipboardWatcher {
    let changes = PassthroughSubject<String, Never>()

    private static let concealed = NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")
    private static let transient = NSPasteboard.PasteboardType("org.nspasteboard.TransientType")
    private var timer: Timer?
    private var changeCount = NSPasteboard.general.changeCount

    func start() {
        guard timer == nil else { return }
        changeCount = NSPasteboard.general.changeCount
        timer = .every(0.7) { [weak self] in self?.poll() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let pasteboard = NSPasteboard.general
        guard pasteboard.changeCount != changeCount else { return }
        changeCount = pasteboard.changeCount
        let types = pasteboard.types ?? []
        guard !types.contains(Self.concealed), !types.contains(Self.transient),
              let text = pasteboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return }
        changes.send(text)
    }
}
