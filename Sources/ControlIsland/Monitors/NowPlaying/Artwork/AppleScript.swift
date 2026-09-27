import Foundation

enum AppleScript {
    static func string(_ source: String) async -> String? {
        await run(source) { $0.stringValue }
    }

    static func data(_ source: String) async -> Data? {
        await run(source) { $0.data }
    }

    private static func run<T: Sendable>(_ source: String, _ extract: @escaping @Sendable (NSAppleEventDescriptor) -> T?) async -> T? {
        await Task.detached(priority: .utility) {
            var error: NSDictionary?
            guard let result = NSAppleScript(source: source)?.executeAndReturnError(&error), error == nil else { return nil }
            return extract(result)
        }.value
    }
}
