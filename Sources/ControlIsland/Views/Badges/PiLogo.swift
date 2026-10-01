import SwiftUI

/// Pi's logo: a π built from a 4×4 grid of coloured cells.
struct PiLogo: View {
    private static let blocks: [(Color, [(Int, Int)])] = [
        (Color(red: 0.94, green: 0.565, blue: 0.51), [(0, 0), (1, 0), (2, 0), (2, 1)]),
        (Color(red: 0.30, green: 0.60, blue: 0.75), [(0, 1), (0, 2), (0, 3), (1, 2)]),
        (Color(red: 0.945, green: 0.745, blue: 0.345), [(3, 2), (3, 3)]),
    ]

    var body: some View {
        Canvas { context, size in
            let cell = size.width / 4
            for (color, cells) in Self.blocks {
                var path = Path()
                for (x, y) in cells {
                    path.addRect(CGRect(x: CGFloat(x) * cell, y: CGFloat(y) * cell, width: cell, height: cell))
                }
                context.fill(path, with: .color(color))
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
