import Foundation

enum DebugLog {
    private static let isEnabled = ProcessInfo.processInfo.environment["ISLAND_DEBUG"] != nil

    static func write(_ message: @autoclosure () -> String) {
        guard isEnabled else { return }
        FileHandle.standardError.write(Data((message() + "\n").utf8))
    }
}
