import Foundation

/// Runs a plugin's executable and exchanges JSON lines with it.
final class PluginProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private var buffer = Data()
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    var isRunning: Bool { process.isRunning }

    init(executable: URL, folder: URL, onMessage: @escaping (PluginMessage) -> Void, onExit: @escaping (Int32) -> Void) {
        let (launch, arguments) = Self.launcher(for: executable)
        process.executableURL = launch
        process.arguments = arguments
        process.currentDirectoryURL = folder
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
        process.terminationHandler = { onExit($0.terminationStatus) }
        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                buffer.removeSubrange(...newline)
                if let message = try? decoder.decode(PluginMessage.self, from: line) { onMessage(message) }
            }
        }
    }

    func start() throws {
        try process.run()
    }

    func send(_ event: PluginEvent) {
        guard process.isRunning, let data = try? encoder.encode(event) else { return }
        input.fileHandleForWriting.write(data + Data("\n".utf8))
    }

    func terminate() {
        output.fileHandleForReading.readabilityHandler = nil
        if process.isRunning { process.terminate() }
    }

    /// Executables run as they are; scripts without the executable bit go through their interpreter.
    private static func launcher(for executable: URL) -> (URL, [String]) {
        if FileManager.default.isExecutableFile(atPath: executable.path) { return (executable, []) }
        let interpreter: String
        switch executable.pathExtension.lowercased() {
        case "py": interpreter = "python3"
        case "sh", "zsh": interpreter = "zsh"
        case "rb": interpreter = "ruby"
        case "js", "mjs": interpreter = "node"
        case "swift": interpreter = "swift"
        default: interpreter = "sh"
        }
        return (URL(fileURLWithPath: "/usr/bin/env"), [interpreter, executable.path])
    }
}
