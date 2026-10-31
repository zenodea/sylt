import Foundation

// MediaRemote accepts commands from any process; simulated media keys no longer reach players.
enum MediaRemoteCommands {
    enum Command: Int32 {
        case togglePlayPause = 2
        case next = 4
        case previous = 5
    }

    private typealias SendFn = @convention(c) (Int32, UnsafeRawPointer?) -> Bool
    private typealias SetElapsedFn = @convention(c) (Double) -> Void

    private static let framework = PrivateFramework(private: "MediaRemote")
    private static let sendFn = framework.symbol("MRMediaRemoteSendCommand", as: SendFn.self)
    private static let setElapsedFn = framework.symbol("MRMediaRemoteSetElapsedTime", as: SetElapsedFn.self)

    static func send(_ command: Command) {
        _ = sendFn?(command.rawValue, nil)
    }

    static func seek(to seconds: TimeInterval) {
        setElapsedFn?(seconds)
    }
}
