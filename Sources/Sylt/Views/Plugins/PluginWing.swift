import SwiftUI

/// One plugin's badge, nothing when it has no items.
struct PluginWing: View {
    @ObservedObject var plugin: ExternalPlugin

    var body: some View {
        if plugin.isRunning, !plugin.wingItems.isEmpty {
            PluginBadge(items: plugin.wingItems, spacing: plugin.wingSpacing)
        }
    }
}
