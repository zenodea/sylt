import Foundation

/// Hosts the adapter dylib inside Apple-signed perl, which is allowed to use MediaRemote.
final class MediaRemoteAdapterProcess {
    private var process: Process?
    private var input: FileHandle?
    private var reader: JSONLineReader<NowPlayingPayload>?

    static var libraryURL: URL? {
        let name = "libMediaRemoteAdapter.dylib"
        let candidates = [
            Bundle.main.privateFrameworksURL?.appendingPathComponent(name),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(name),
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func start(onPayload: @escaping (NowPlayingPayload) -> Void) {
        guard process == nil, let library = Self.libraryURL else { return }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [
            "-e", "require DynaLoader; DynaLoader::dl_load_file($ARGV[0], 0) or die DynaLoader::dl_error(); sleep",
            "--", library.path,
        ]
        let stdin = Pipe()
        let stdout = Pipe()
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        reader = JSONLineReader(stdout.fileHandleForReading, onMessage: onPayload)
        do {
            try process.run()
            self.process = process
            input = stdin.fileHandleForWriting
        } catch {
            JSONLineReader<NowPlayingPayload>.stop(stdout.fileHandleForReading)
            reader = nil
        }
    }

    func send(_ command: String) {
        try? input?.write(contentsOf: Data((command + "\n").utf8))
    }

    func stop() {
        if let stdout = process?.standardOutput as? Pipe { JSONLineReader<NowPlayingPayload>.stop(stdout.fileHandleForReading) }
        process?.terminate()
        process = nil
        input = nil
        reader = nil
    }
}
