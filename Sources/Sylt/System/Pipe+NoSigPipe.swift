import Foundation

extension Pipe {
    // Writing after the child has gone must fail with EPIPE, not raise SIGPIPE and end the app.
    static func toChild() -> Pipe {
        let pipe = Pipe()
        _ = fcntl(pipe.fileHandleForWriting.fileDescriptor, F_SETNOSIGPIPE, 1)
        return pipe
    }
}
