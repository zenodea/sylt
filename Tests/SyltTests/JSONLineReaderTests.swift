import XCTest
@testable import Sylt

final class JSONLineReaderTests: XCTestCase {
    private struct Message: Decodable, Equatable { let n: Int }

    func testLinesSplitAcrossChunksAndBadLinesAreSkipped() {
        let pipe = Pipe()
        let third = expectation(description: "three messages")
        var received: [Message] = []
        let reader = JSONLineReader<Message>(pipe.fileHandleForReading) { message in
            received.append(message)
            if received.count == 3 { third.fulfill() }
        }
        pipe.fileHandleForWriting.write(Data("{\"n\": 1}\n{\"n\"".utf8))
        pipe.fileHandleForWriting.write(Data(": 2}\nnot json\n{\"n\": 3}\n".utf8))
        wait(for: [third], timeout: 2)
        XCTAssertEqual(received, [Message(n: 1), Message(n: 2), Message(n: 3)])
        withExtendedLifetime(reader) {}
    }

    func testEndOfFileReleasesTheHandler() {
        let pipe = Pipe()
        let reader = JSONLineReader<Message>(pipe.fileHandleForReading) { _ in }
        XCTAssertNotNil(pipe.fileHandleForReading.readabilityHandler)
        pipe.fileHandleForWriting.closeFile()
        let released = expectation(description: "handler cleared")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) {
            if pipe.fileHandleForReading.readabilityHandler == nil { released.fulfill() }
        }
        wait(for: [released], timeout: 2)
        withExtendedLifetime(reader) {}
    }
}
