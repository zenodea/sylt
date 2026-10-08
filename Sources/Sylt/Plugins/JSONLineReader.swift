import Foundation

/// Decodes newline-delimited JSON as it arrives on a pipe, one message per line.
final class JSONLineReader<Message: Decodable> {
    private var buffer = Data()
    private let decoder = JSONDecoder()

    init(_ handle: FileHandle, onMessage: @escaping (Message) -> Void) {
        handle.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            // At end of file the handler would otherwise be called again at once, forever.
            guard let self, !chunk.isEmpty else { handle.readabilityHandler = nil; return }
            buffer.append(chunk)
            while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
                let line = buffer[..<newline]
                buffer.removeSubrange(...newline)
                if let message = try? decoder.decode(Message.self, from: line) { onMessage(message) }
            }
        }
    }

    static func stop(_ handle: FileHandle) {
        handle.readabilityHandler = nil
    }
}
