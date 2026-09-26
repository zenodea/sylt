import SwiftUI

struct MediaCard: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor

    var body: some View {
        if let track = nowPlaying.track {
            HStack(spacing: 14) {
                ArtworkView(image: track.artwork, size: 64)
                VStack(alignment: .leading, spacing: 6) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    }
                    PlaybackProgress(nowPlaying: nowPlaying, duration: track.duration)
                    controls
                }
            }
            .padding(12)
            .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private var controls: some View {
        HStack(spacing: 22) {
            TransportButton(symbol: "backward.fill", action: nowPlaying.previous)
            TransportButton(symbol: nowPlaying.isPlaying ? "pause.fill" : "play.fill", size: 18, action: nowPlaying.togglePlayPause)
            TransportButton(symbol: "forward.fill", action: nowPlaying.next)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct PlaybackProgress: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor
    let duration: TimeInterval?

    var body: some View {
        TimelineView(.periodic(from: .now, by: nowPlaying.isPlaying ? 0.5 : 60)) { context in
            let elapsed = nowPlaying.position.elapsed(at: context.date)
            let total = duration ?? 0
            HStack(spacing: 8) {
                Text(timestamp(elapsed))
                LevelBar(value: total > 0 ? min(elapsed / total, 1) : 0)
                Text(timestamp(total))
            }
            .font(.system(size: 10, weight: .medium, design: .rounded).monospacedDigit())
            .foregroundStyle(.white.opacity(0.6))
        }
    }

    private func timestamp(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.down))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct TransportButton: View {
    let symbol: String
    var size: CGFloat = 14
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size, weight: .bold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(.white)
    }
}
