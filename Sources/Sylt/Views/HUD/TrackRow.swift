import SwiftUI

struct TrackRow: View {
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor

    var body: some View {
        if let track = nowPlaying.track {
            HUDRow(title: track.title, detail: track.artist)
        }
    }
}
