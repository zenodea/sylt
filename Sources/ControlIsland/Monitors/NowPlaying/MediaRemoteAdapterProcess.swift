import Foundation

/// Hosts the adapter dylib inside Apple-signed perl, which is allowed to use MediaRemote.
final class MediaRemoteAdapterProcess {
    private var process: Process?
    private var input: FileHandle?
    private var buffer = Data()
    private let decoder = JSONDecoder()

    static var libraryURL: URL? {
        let name = "libMediaRemoteAdapter.dylib"
        let candidates = [
            Bundle.main.privateFrameworksURL?.appendingPathComponent(name),
            Bundle.main.executableURL?.deletingLastPathComponent().appendingPathComponent(name),
        ]
        return candidates.compactMap { $0 }.first { FileManager.default.fileExists(atPath: $0.path) }
    }

    func start(onPayload: @escaping (NowPlayingPayload) -> Void) {
        guard let library = Self.libraryURL else { return }
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

        stdout.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                buffer.removeSubrange(...newline)
                if let payload = try? decoder.decode(NowPlayingPayload.self, from: line) {
                    onPayload(payload)
                }
            }
        }

        do {
            try process.run()
            self.process = process
            self.input = stdin.fileHandleForWriting
        } catch {
            stdout.fileHandleForReading.readabilityHandler = nil
        }
    }

    func send(_ command: String) {
        input?.write(Data((command + "\n").utf8))
    }

    func stop() {
        process?.terminate()
        process = nil
        input = nil
    }
}
