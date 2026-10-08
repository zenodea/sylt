import SwiftUI

struct PluginWing: View {
    @ObservedObject var plugin: ExternalPlugin

    var body: some View {
        if plugin.isRunning, !plugin.wingItems.isEmpty {
            PluginBadge(items: plugin.wingItems, spacing: plugin.wingSpacing)
        }
    }
}
