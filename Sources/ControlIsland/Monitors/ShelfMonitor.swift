import Combine
import Foundation

/// Files parked on the island, dragged in to hold and dragged out to use.
@MainActor
final class ShelfMonitor: ObservableObject {
    @Published private(set) var files: [URL] = []

    private static let key = "shelfPaths"
    private var cancellable: AnyCancellable?

    func start() {
        guard cancellable == nil else { return }
        files = (UserDefaults.standard.stringArray(forKey: Self.key) ?? [])
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        cancellable = $files
            .dropFirst()
            .sink { UserDefaults.standard.set($0.map(\.path), forKey: Self.key) }
    }

    func stop() {
        cancellable = nil
        files = []
    }

    func add(_ urls: [URL]) {
        for url in urls where !files.contains(url) { files.append(url) }
    }

    func remove(_ url: URL) {
        files.removeAll { $0 == url }
    }

    func clear() {
        files = []
    }
}
