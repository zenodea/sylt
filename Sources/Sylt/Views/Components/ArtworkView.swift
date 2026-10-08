import SwiftUI

/// Album art; a new cover flips the tile over, the image swapping mid-turn.
struct ArtworkView: View {
    let image: NSImage?
    let size: CGFloat
    @State private var turns = 0.0
    @State private var pop = false

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .id(ObjectIdentifier(image))
                    .transition(.opacity)
            } else {
                ZStack {
                    Color.white.opacity(0.12)
                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.45, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.22, style: .continuous))
        .rotation3DEffect(.degrees(turns * 360), axis: (x: 0, y: 1, z: 0), perspective: 0.6)
        .scaleEffect(pop ? 1.18 : 1)
        .animation(.easeInOut(duration: 0.25).delay(0.2), value: image.map(ObjectIdentifier.init))
        .onChange(of: image.map(ObjectIdentifier.init)) { before, _ in
            guard before != nil else { return }
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) { turns += 1 }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) { pop = true }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6).delay(0.3)) { pop = false }
        }
    }
}
