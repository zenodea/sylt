import Foundation

/// Playback commands through MediaRemote, which still accepts them from any process
/// even though it withholds metadata. Simulated media keys no longer reach players.
enum MediaRemoteCommands {
    enum Command: Int32 {
        case play = 0
        case pause = 1
        case togglePlayPause = 2
        case next = 4
        case previous = 5
    }

    private typealias SendFn = @convention(c) (Int32, UnsafeRawPointer?) -> Bool
    private typealias SetElapsedFn = @convention(c) (Double) -> Void

    private static let handle = dlopen("/System/Library/PrivateFrameworks/MediaRemote.framework/MediaRemote", RTLD_NOW)
    private static let sendFn: SendFn? = handle.flatMap { dlsym($0, "MRMediaRemoteSendCommand") }.map { unsafeBitCast($0, to: SendFn.self) }
    private static let setElapsedFn: SetElapsedFn? = handle.flatMap { dlsym($0, "MRMediaRemoteSetElapsedTime") }.map { unsafeBitCast($0, to: SetElapsedFn.self) }

    @discardableResult
    static func send(_ command: Command) -> Bool {
        sendFn?(command.rawValue, nil) ?? false
    }

    static func seek(to seconds: TimeInterval) {
        setElapsedFn?(seconds)
    }
}
