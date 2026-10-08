/// What the island does when it lets the pointer go.
enum ReleaseEffect: String, CaseIterable, Identifiable {
    case ripple = "splash", ring, glass, sparks, blackHole, none

    var id: String { rawValue }

    var title: String {
        switch self {
        case .ripple: "Ripple"
        case .ring: "Ring of light"
        case .glass: "Liquid glass"
        case .sparks: "Sparks"
        case .blackHole: "Black hole"
        case .none: "Nothing"
        }
    }
}
