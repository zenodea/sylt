import SwiftUI

struct TrackRow: View {
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor

    var body: some View {
        if let track = nowPlaying.track {
            HUDRow(text: track.artist.isEmpty ? track.title : "\(track.title)  ·  \(track.artist)")
        }
    }
}
