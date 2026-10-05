import AppKit
import Combine
import Foundation

/// One plugin folder, running or not, and what it currently shows.
@MainActor
final class ExternalPlugin: ObservableObject, Identifiable {
    let manifest: PluginManifest
    let folder: URL
    let isBundled: Bool

    @Published private(set) var left: [PluginItem] = []
    @Published private(set) var right: [PluginItem] = []
    @Published private(set) var leftSpacing: CGFloat = 8
    @Published private(set) var rightSpacing: CGFloat = 8
    @Published private(set) var section: PluginSection?
    @Published private(set) var isRunning = false
    let huds = PassthroughSubject<PluginHUD, Never>()

    var id: String { manifest.id }

    /// Everything the plugin put in a wing, left items first. The user picks the side.
    var wingItems: [PluginItem] { left + right }
    var wingSpacing: CGFloat { left.isEmpty ? rightSpacing : leftSpacing }

    /// The side the plugin would take on its own: what its manifest says, else where it
    /// last put something, else the right.
    var wingPlugin: WingPlugin {
        let declared = manifest.side.flatMap(WingSide.init(rawValue:))
        return WingPlugin(id: id, side: declared ?? (!left.isEmpty && right.isEmpty ? .left : .right))
    }

    private let store: PluginStore
    private var process: PluginProcess?
    private var ticker: Timer?
    private var restart: Timer?
    private var stopping = false
    private var crashes = 0

    init(manifest: PluginManifest, folder: URL, isBundled: Bool, store: PluginStore) {
        self.manifest = manifest
        self.folder = folder
        self.isBundled = isBundled
        self.store = store
    }

    var dataDirectory: URL {
        let url = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Sylt/PluginData/\(manifest.id)", isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    func start() {
        guard !isRunning else { return }
        stopping = false
        crashes = 0
        isRunning = true
        if let interval = manifest.interval {
            runOnce()
            ticker = .every(interval) { [weak self] in self?.runOnce() }
        } else {
            launch()
        }
    }

    func stop() {
        stopping = true
        isRunning = false
        ticker?.invalidate()
        ticker = nil
        restart?.invalidate()
        restart = nil
        process?.send(PluginEvent(event: "stop"))
        process?.terminate()
        process = nil
        left = []
        right = []
        section = nil
    }

    func send(_ event: PluginEvent) {
        process?.send(event)
    }

    func settingsChanged() {
        send(PluginEvent(event: "settings", settings: store.values(for: manifest)))
        if manifest.isOneShot { runOnce() }
    }

    private func launch() {
        let executable = folder.appendingPathComponent(manifest.run)
        let process = PluginProcess(
            executable: executable, folder: folder,
            onMessage: { [weak self] message in Task { @MainActor in self?.handle(message) } },
            onExit: { [weak self] status in Task { @MainActor in self?.exited(status) } }
        )
        do {
            try process.start()
            self.process = process
            process.send(PluginEvent(event: "start", settings: store.values(for: manifest), dataDir: dataDirectory.path, protocol: PluginProtocol.version))
        } catch {
            isRunning = false
        }
    }

    private func runOnce() {
        process?.terminate()
        launch()
    }

    /// A long-running plugin that dies comes back, slower each time.
    private func exited(_ status: Int32) {
        process = nil
        guard !stopping, !manifest.isOneShot else { return }
        crashes += 1
        guard crashes <= 5 else { isRunning = false; return }
        restart = .after(Double(crashes) * 2) { [weak self] in self?.launch() }
    }

    private func handle(_ message: PluginMessage) {
        if let wing = message.wing {
            let spacing = CGFloat(wing.spacing ?? 8)
            if wing.side == "left" { leftSpacing = spacing; left = wing.items ?? [] } else { rightSpacing = spacing; right = wing.items ?? [] }
        }
        if let section = message.section { self.section = section }
        if message.clearSection == true { section = nil }
        if let hud = message.hud { huds.send(hud) }
        if let sound = message.sound { NSSound(named: sound)?.play() }
        if let activation = message.activate { activate(activation) }
        if let target = message.open {
            if let url = URL(string: target), url.scheme != nil, !target.hasPrefix("/") { NSWorkspace.shared.open(url) }
            else { NSWorkspace.shared.open(URL(fileURLWithPath: target)) }
        }
    }

    private func activate(_ activation: PluginActivation) {
        let host: NSRunningApplication?
        if let pid = activation.pid { host = ProcessTree.hostApplication(ofProcess: pid) }
        else if let name = activation.process { host = ProcessTree.hostApplication(ofProcessNamed: name) }
        else if let bundle = activation.bundle { host = NSRunningApplication.runningApplications(withBundleIdentifier: bundle).first }
        else { host = nil }
        guard let host else { return }
        NSApp.yieldActivation(to: host)
        host.activate()
        if let window = activation.window {
            Timer.after(0.3) { WindowRaiser.raise(in: host, titleContaining: window) }
        }
    }
}
