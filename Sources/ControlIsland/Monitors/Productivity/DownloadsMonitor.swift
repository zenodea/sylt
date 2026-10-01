import Combine
import Foundation

/// Browser downloads landing in ~/Downloads, from their partial files.
@MainActor
final class DownloadsMonitor: ObservableObject {
    enum Event: Hashable {
        case started(String)
        case finished(String)

        var name: String {
            switch self {
            case .started(let name), .finished(let name): name
            }
        }
    }

    @Published private(set) var active: Set<String> = []
    let events = PassthroughSubject<Event, Never>()

    nonisolated private static let partialExtensions: Set<String> = ["download", "crdownload", "part", "partial", "tmp"]
    private let folder = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
    private var source: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1
    private var primed = false

    func start() {
        guard source == nil else { return }
        descriptor = open(folder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: .write, queue: .main)
        source.setEventHandler { [weak self] in self?.refresh() }
        source.resume()
        self.source = source
        refresh()
    }

    func stop() {
        source?.cancel()
        source = nil
        if descriptor >= 0 { close(descriptor) }
        descriptor = -1
        active = []
        primed = false
    }

    /// Base names of in-progress downloads among the folder's file names.
    nonisolated static func partialNames(in names: [String]) -> Set<String> {
        Set(names.filter { partialExtensions.contains(($0 as NSString).pathExtension.lowercased()) }
            .map { ($0 as NSString).deletingPathExtension })
    }

    private func refresh() {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
        let partials = Self.partialNames(in: names)
        defer { primed = true; active = partials }
        guard primed else { return }
        for name in partials.subtracting(active) { events.send(.started(name)) }
        for name in active.subtracting(partials) where names.contains(where: { $0.hasPrefix(name) }) { events.send(.finished(name)) }
    }
}
