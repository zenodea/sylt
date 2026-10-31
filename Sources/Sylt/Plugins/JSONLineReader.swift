import Foundation

final class JSONLineReader<Message: Decodable> {
    private let handle: FileHandle
    private var buffer = Data()
    private let decoder = JSONDecoder()

    init(_ handle: FileHandle, onMessage: @escaping (Message) -> Void) {
        self.handle = handle
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

    func stop() {
        handle.readabilityHandler = nil
    }
}
