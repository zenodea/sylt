import Foundation

/// Runs a plugin's executable and exchanges JSON lines with it.
final class PluginProcess {
    private let process = Process()
    private let input = Pipe()
    private let output = Pipe()
    private let encoder = JSONEncoder()
    private var reader: JSONLineReader<PluginMessage>?

    var isRunning: Bool { process.isRunning }

    init(executable: URL, folder: URL) {
        let (launch, arguments) = Self.launcher(for: executable)
        process.executableURL = launch
        process.arguments = arguments
        process.currentDirectoryURL = folder
        process.standardInput = input
        process.standardOutput = output
        process.standardError = FileHandle.nullDevice
    }

    func start(onMessage: @escaping (PluginMessage) -> Void, onExit: @escaping () -> Void) throws {
        reader = JSONLineReader(output.fileHandleForReading, onMessage: onMessage)
        process.terminationHandler = { _ in onExit() }
        try process.run()
    }

    func send(_ event: PluginEvent) {
        guard process.isRunning, let data = try? encoder.encode(event) else { return }
        // A plugin that closed its stdin is on its way out; the exit handler deals with it.
        try? input.fileHandleForWriting.write(contentsOf: data + Data("\n".utf8))
    }

    func terminate() {
        JSONLineReader<PluginMessage>.stop(output.fileHandleForReading)
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
