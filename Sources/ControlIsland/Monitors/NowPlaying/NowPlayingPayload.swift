import Foundation

struct NowPlayingPayload: Decodable {
    var title: String?
    var artist: String?
    var album: String?
    var duration: Double?
    var elapsed: Double?
    var rate: Double?
    var playing: Bool
    var bundle: String?
    var timestamp: Double?
    var artworkHash: UInt
    var artwork: String?
}
