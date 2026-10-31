import Foundation

// Hosted inside Apple-signed perl, which MediaRemote still serves metadata to.
final class MediaRemoteAdapterProcess {
    private var process: Process?
    private var input: FileHandle?
    private var reader: JSONLineReader<NowPlayingPayload>?
    private var onPayload: ((NowPlayingPayload) -> Void)?
    private var restartDelay: TimeInterval = 2
    private static let longestRestartDelay: TimeInterval = 60

    private static var libraryURL: URL? {
        let name = "libMediaRemoteAdapter.dylib"
        let candidates = [
            Bundle.main.privateFrameworksURL?.appendingPathComponent(name),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(name),
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func start(onPayload: @escaping (NowPlayingPayload) -> Void) {
        guard process == nil, let library = Self.libraryURL else { return }
        self.onPayload = onPayload
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            "-e", "require DynaLoader; DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error(); sleep",
            "--", library.path,
        ]
        let stdin = Pipe.toChild()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        reader = JSONLineReader(stdout.fileHandleForReading, onMessage: onPayload)
        process.terminationHandler = { [weak self] ended in
            DispatchQueue.main.async {
                guard let self, self.process == ended, let onPayload = self.onPayload else { return }
                self.stop()
                let delay = self.restartDelay
                self.restartDelay = min(delay * 2, Self.longestRestartDelay)
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    guard let self, self.process == nil, self.onPayload != nil else { return }
                    self.start(onPayload: onPayload)
                }
            }
        }
        do {
            try process.run()
            self.process = process
            input = stdin.fileHandleForWriting
        } catch {
            reader?.stop()
            reader = nil
        }
    }

    func requestRefresh() {
        try? input?.write(contentsOf: Data("refresh\n".utf8))
    }

    func stop() {
        reader?.stop()
        process?.terminationHandler = nil
        process?.terminate()
        process = nil
        input = nil
        reader = nil
    }

    func shutDown() {
        onPayload = nil
        stop()
    }
}
