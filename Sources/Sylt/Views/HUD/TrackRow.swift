import SwiftUI

/// Title and artist under the notch while a track change shows.
struct TrackRow: View {
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor

    var body: some View {
        if let track = nowPlaying.track {
            MarqueeText(text: track.artist.isEmpty ? track.title : "\(track.title)  ·  \(track.artist)")
                .foregroundStyle(.white.opacity(0.85))
                .frame(height: IslandLayout.hudRowHeight)
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
        }
    }
}
