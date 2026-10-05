import Combine
import Foundation

/// Finds plugin folders, bundled and user-installed, and keeps them running
/// while enabled. The user folder is watched, so dropping a plugin in is enough.
@MainActor
final class PluginRegistry: ObservableObject {
    @Published private(set) var plugins: [ExternalPlugin] = []
    let huds = PassthroughSubject<(ExternalPlugin, PluginHUD), Never>()

    let store: PluginStore
    private let clipboard = ClipboardWatcher()
    private var cancellables = Set<AnyCancellable>()
    private var pluginCancellables: [String: AnyCancellable] = [:]
    private var watcher: DispatchSourceFileSystemObject?
    private var descriptor: Int32 = -1

    static let userFolder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("Sylt/Plugins", isDirectory: true)

    init(store: PluginStore) {
        self.store = store
        clipboard.changes
            .sink { [weak self] text in
                for plugin in self?.plugins ?? [] where plugin.manifest.wantsClipboard && plugin.isRunning {
                    plugin.send(PluginEvent(event: "clipboard", text: text))
                }
            }
            .store(in: &cancellables)
    }

    func start() {
        try? FileManager.default.createDirectory(at: Self.userFolder, withIntermediateDirectories: true)
        reload()
        watch()
    }

    func stop() {
        plugins.forEach { $0.stop() }
        clipboard.stop()
        watcher?.cancel()
        watcher = nil
        if descriptor >= 0 { close(descriptor) }
        descriptor = -1
    }

    /// Rescans both folders; plugins that vanished stop, new ones start.
    func reload() {
        let found = (Self.scan(Self.bundledFolder, bundled: true) + Self.scan(Self.userFolder, bundled: false))
        var next: [ExternalPlugin] = []
        var seen: Set<String> = []
        for (manifest, folder, bundled) in found where !seen.contains(manifest.id) {
            seen.insert(manifest.id)
            if let existing = plugins.first(where: { $0.id == manifest.id && $0.manifest == manifest && $0.folder == folder }) {
                next.append(existing)
            } else {
                next.append(ExternalPlugin(manifest: manifest, folder: folder, isBundled: bundled, store: store))
            }
        }
        for plugin in plugins where !next.contains(where: { $0 === plugin }) {
            plugin.stop()
            pluginCancellables[plugin.id] = nil
        }
        plugins = next
        for plugin in plugins {
            pluginCancellables[plugin.id] = plugin.huds.sink { [weak self, weak plugin] hud in
                guard let self, let plugin, store.showsHUDs(plugin.manifest) else { return }
                huds.send((plugin, hud))
            }
            applyEnabled(plugin)
        }
        watchClipboardIfWanted()
    }

    func setShowsHUDs(_ on: Bool, _ plugin: ExternalPlugin) {
        store.setShowsHUDs(on, plugin.manifest)
    }

    private func watchClipboardIfWanted() {
        plugins.contains { $0.manifest.wantsClipboard && store.isEnabled($0.manifest) } ? clipboard.start() : clipboard.stop()
    }

    func setEnabled(_ on: Bool, _ plugin: ExternalPlugin) {
        store.setEnabled(on, plugin.manifest)
        applyEnabled(plugin)
        watchClipboardIfWanted()
    }

    func isEnabled(_ plugin: ExternalPlugin) -> Bool { store.isEnabled(plugin.manifest) }

    func dropped(_ urls: [URL]) {
        for plugin in plugins where plugin.manifest.acceptsFiles && plugin.isRunning {
            plugin.send(PluginEvent(event: "drop", files: urls.map(\.path)))
        }
    }

    private func applyEnabled(_ plugin: ExternalPlugin) {
        store.isEnabled(plugin.manifest) ? plugin.start() : plugin.stop()
    }

    private static var bundledFolder: URL? {
        if let override = ProcessInfo.processInfo.environment["ISLAND_PLUGINS"] { return URL(fileURLWithPath: override) }
        return Bundle.main.resourceURL?.appendingPathComponent("Plugins")
    }

    private static func scan(_ root: URL?, bundled: Bool) -> [(PluginManifest, URL, Bool)] {
        guard let root, let folders = try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil) else { return [] }
        return folders.compactMap { folder in
            guard let data = try? Data(contentsOf: folder.appendingPathComponent("plugin.json")),
                  let manifest = try? JSONDecoder().decode(PluginManifest.self, from: data),
                  manifest.protocolVersion == PluginProtocol.version
            else { return nil }
            return (manifest, folder, bundled)
        }
        .sorted { $0.0.name < $1.0.name }
    }

    private func watch() {
        descriptor = open(Self.userFolder.path, O_EVTONLY)
        guard descriptor >= 0 else { return }
        let source = DispatchSource.makeFileSystemObjectSource(fileDescriptor: descriptor, eventMask: [.write, .rename, .delete], queue: .main)
        source.setEventHandler { [weak self] in self?.reload() }
        source.resume()
        watcher = source
    }
}
