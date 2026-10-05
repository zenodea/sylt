import SwiftUI

struct MediaCard: View {
    @ObservedObject var nowPlaying: NowPlayingMonitor
    @EnvironmentObject private var volume: VolumeMonitor

    var body: some View {
        if let track = nowPlaying.track {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    ArtworkView(image: track.artwork, size: 60)
                        .overlay(alignment: .bottomTrailing) {
                            sourceBadge(for: track).offset(x: 5, y: 5)
                        }
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
                output
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

    /// The source app. With more than one player going, it is a menu to pick which to show.
    @ViewBuilder
    private func sourceBadge(for track: NowPlayingTrack) -> some View {
        if nowPlaying.sources.count > 1 {
            Menu {
                ForEach(nowPlaying.sources, id: \.self) { bundle in
                    Button {
                        nowPlaying.select(source: bundle)
                    } label: {
                        if let icon = AppIcons.icon(for: bundle) { Image(nsImage: icon) }
                        Text(AppIcons.name(for: bundle))
                        if bundle == track.bundleIdentifier { Image(systemName: "checkmark") }
                    }
                }
            } label: {
                SourceBadge(bundleIdentifier: track.bundleIdentifier)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 6, weight: .black))
                            .foregroundStyle(.white)
                            .padding(2)
                            .background(.black, in: Circle())
                            .offset(x: 4, y: -4)
                    }
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .fixedSize()
        } else {
            SourceBadge(bundleIdentifier: track.bundleIdentifier)
        }
    }

    /// Where the sound goes, and how loud.
    private var output: some View {
        HStack(spacing: 8) {
            LevelSlider(symbol: volume.isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill", value: volume.isMuted ? 0 : volume.level) {
                volume.set($0)
            }
            Text(volume.outputName)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
                .frame(maxWidth: 120, alignment: .trailing)
        }
        .padding(.horizontal, 2)
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
