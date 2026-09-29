import SwiftUI

struct MediaCard: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor

    var body: some View {
        if let track = nowPlaying.track {
            HStack(spacing: 12) {
                ArtworkView(image: track.artwork, size: 60)
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
            .padding(10)
            .background(
                LinearGradient(
                    colors: [track.tint.opacity(0.22), track.tint.opacity(0.08)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ),
                in: RoundedRectangle(cornerRadius: 14, style: .continuous)
            )
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        LinearGradient(colors: track.barColors, startPoint: .leading, endPoint: .trailing).opacity(0.75),
                        lineWidth: 1
                    )
            )
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
    @State private var scrubbing: Double?

    var body: some View {
        TimelineView(.periodic(from: .now, by: nowPlaying.isPlaying ? 0.5 : 60)) { context in
            let total = duration ?? 0
            let elapsed = scrubbing.map { $0 * total } ?? nowPlaying.position.elapsed(at: context.date)
            HStack(spacing: 8) {
                Text(timestamp(elapsed))
                GeometryReader { geo in
                    LevelBar(value: total > 0 ? min(elapsed / total, 1) : 0)
                        .frame(height: 6)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { scrubbing = min(max($0.location.x / geo.size.width, 0), 1) }
                                .onEnded { value in
                                    let fraction = min(max(value.location.x / geo.size.width, 0), 1)
                                    scrubbing = nil
                                    if total > 0 { nowPlaying.seek(to: fraction * total) }
                                    Haptics.press()
                                }
                        )
                }
                .frame(height: 14)
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
    @State private var pressed = false

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size, weight: .bold))
            .frame(width: 30, height: 30)
            .background(.white.opacity(pressed ? 0.14 : 0), in: Circle())
            .scaleEffect(pressed ? 0.88 : 1)
            .contentShape(Circle())
            .foregroundStyle(.white)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        guard !pressed else { return }
                        withAnimation(IslandAnimation.press) { pressed = true }
                        Haptics.press()
                    }
                    .onEnded { _ in
                        withAnimation(IslandAnimation.press) { pressed = false }
                        action()
                    }
            )
    }
}
