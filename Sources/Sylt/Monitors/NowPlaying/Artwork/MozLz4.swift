import Compression
import Foundation

enum MozLz4 {
    private static let magic = Data("mozLz40\0".utf8)

    static func decompress(_ data: Data) -> Data? {
        guard data.count > 12, data.prefix(8) == magic else { return nil }
        let size = data.subdata(in: 8..<12).withUnsafeBytes { Int($0.loadUnaligned(as: UInt32.self).littleEndian) }
        guard size > 0, size < 256 * 1024 * 1024 else { return nil }

        var output = Data(count: size)
        let written = output.withUnsafeMutableBytes { destination in
            data.withUnsafeBytes { source -> Int in
                guard let dst = destination.baseAddress, let src = source.baseAddress else { return 0 }
                return compression_decode_buffer(
                    dst.assumingMemoryBound(to: UInt8.self), size,
                    src.assumingMemoryBound(to: UInt8.self).advanced(by: 12), data.count - 12,
                    nil, COMPRESSION_LZ4_RAW
                )
            }
        }
        guard written == size else { return nil }
        return output
    }
}
