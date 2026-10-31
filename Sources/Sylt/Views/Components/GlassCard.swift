import SwiftUI

extension View {
    // Glass lights its rim from what is behind it and the black underneath gives it nothing,
    // so a drawn rim, bright where top-left light would catch it, stands in.
    @MainActor
    @ViewBuilder
    func glassCard(in shape: some InsettableShape, tint: Color? = nil, rim: Bool = true, preferences: Preferences) -> some View {
        if preferences.showsGlassCards, preferences.liquidCards, #available(macOS 26, *) {
            background {
                ZStack {
                    shape.fill(.black)
                        .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
                    Color.clear
                        .glassEffect(.regular.tint(tint).interactive(), in: shape)
                        .opacity(preferences.glassCardOpacity)
                }
            }
            .overlay {
                if rim {
                    shape.strokeBorder(GlassRim.gradient, lineWidth: 1)
                }
            }
        } else if preferences.showsGlassCards {
            background {
                shape.fill(.ultraThinMaterial)
                    .overlay { shape.fill(tint ?? .clear) }
                    .opacity(preferences.glassCardOpacity)
                    .shadow(color: .black.opacity(0.6), radius: 8, y: 4)
            }
        } else {
            self
        }
    }
}

extension Preferences {
    var showsGlassCards: Bool { glassCards && GlassCard.isAvailable }
}

enum GlassCard {
    static var isAvailable: Bool {
        if #available(macOS 26, *) { true } else { false }
    }
}

private enum GlassRim {
    static let gradient = LinearGradient(
        stops: [
            .init(color: .white.opacity(0.45), location: 0),
            .init(color: .white.opacity(0.08), location: 0.45),
            .init(color: .white.opacity(0.04), location: 0.7),
            .init(color: .white.opacity(0.2), location: 1),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
