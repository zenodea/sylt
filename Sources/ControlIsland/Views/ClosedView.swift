import SwiftUI

struct ClosedView: View {
    @ObservedObject var state: IslandState
    @EnvironmentObject private var herdr: HerdrMonitor
    @EnvironmentObject private var nowPlaying: NowPlayingMonitor

    var body: some View {
        HStack(spacing: 0) {
            leftWing.frame(width: state.layout.wingWidth)
            Spacer().frame(width: state.notchWidth)
            rightWing.frame(width: state.layout.wingWidth)
        }
        .frame(height: state.notchHeight)
    }

    private var leftWing: some View {
        HStack(spacing: 8) {
            if let track = nowPlaying.track {
                ArtworkView(image: track.artwork, size: state.layout.artworkSize)
            }
            if herdr.available {
                HStack(spacing: 5) {
                    StatusDot(active: herdr.workingCount > 0)
                    Text("\(herdr.workingCount)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
        }
        .padding(.leading, IslandLayout.wingPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var rightWing: some View {
        HStack(spacing: 8) {
            if nowPlaying.track != nil {
                AudioBars(isPlaying: nowPlaying.isPlaying)
            }
        }
        .padding(.trailing, IslandLayout.wingPadding)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }
}
