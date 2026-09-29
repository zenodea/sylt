import SwiftUI

/// A padlock that springs open, and turns green, when `open` flips.
struct LockGlyph: View {
    let open: Bool

    var body: some View {
        Image(systemName: open ? "lock.open.fill" : "lock.fill")
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(open ? Color.green : .white.opacity(0.85))
            .contentTransition(.symbolEffect(.replace.downUp))
            .symbolEffect(.bounce, value: open)
    }
}
