import Foundation

struct PlayerSnapshot: Sendable {
    var title: String
    var artist: String
    var album: String
    var duration: TimeInterval?
    var position: TimeInterval
    var isPlaying: Bool
    /// The app's own volume, 0 to 1.
    var volume: Double?

    init?(descriptor: NSAppleEventDescriptor) {
        guard descriptor.numberOfItems >= 6,
              let title = descriptor.atIndex(1)?.stringValue, !title.isEmpty
        else { return nil }
        self.title = title
        artist = descriptor.atIndex(2)?.stringValue ?? ""
        album = descriptor.atIndex(3)?.stringValue ?? ""
        let seconds = descriptor.atIndex(4)?.doubleValue ?? 0
        duration = seconds > 0 ? seconds : nil
        position = descriptor.atIndex(5)?.doubleValue ?? 0
        isPlaying = descriptor.atIndex(6)?.stringValue == "playing"
        volume = descriptor.atIndex(7).map { Double($0.int32Value) / 100 }
    }
}
