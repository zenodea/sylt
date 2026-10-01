import SwiftUI

/// One plugin's items on one side, nothing when it has none.
struct PluginWing: View {
    @ObservedObject var plugin: ExternalPlugin
    let side: HUDWing.Side

    var body: some View {
        let items = side == .leading ? plugin.left : plugin.right
        if plugin.isRunning, !items.isEmpty {
            PluginBadge(items: items)
        }
    }
}
