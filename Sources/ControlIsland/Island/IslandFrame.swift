import CoreGraphics

/// Where the island sits relative to the notch: its size plus how far its
/// centre is shifted, so a HUD can grow out of one side only.
struct IslandFrame: Equatable {
    var size: CGSize
    var centerOffset: CGFloat
}
