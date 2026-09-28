import SwiftUI

struct ClosedView: View {
    let layout: IslandLayout
    @EnvironmentObject private var herdr: HerdrMonitor
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor

    var body: some View {
        HStack(spacing: 0) {
            leftWing.frame(width: layout.wingWidth)
            Spacer().frame(width: layout.notchWidth)
            rightWing.frame(width: layout.wingWidth)
        }
        .frame(height: layout.notchHeight)
    }

    private var leftWing: some View {
        HStack(spacing: 4) {
            if herdr.available {
                SheepBadge(workingCount: herdr.workingCount)
            }
        }
        .padding(.leading, IslandLayout.wingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rightWing: some View {
        HStack(spacing: 8) {
            if let track = nowPlaying.track {
                ArtworkView(image: track.artwork, size: layout.artworkSize)
                AudioBars(isPlaying: nowPlaying.isPlaying, colors: track.barColors)
            }
        }
        .padding(.trailing, IslandLayout.wingPadding)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
