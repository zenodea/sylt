import SwiftUI

struct PluginsPane: View {
    @ObservedObject var plugins: PluginRegistry

    var body: some View {
        Section {
            ForEach(plugins.plugins) { plugin in
                ExternalPluginRow(plugin: plugin, registry: plugins)
            }
            if plugins.plugins.isEmpty {
                Text("No plugins yet. Drop a folder with a plugin.json into the plugins folder.")
                    .foregroundStyle(.secondary)
            }
            HStack {
                Button("Open plugins folder") { NSWorkspace.shared.open(PluginRegistry.userFolder) }
                Button("Reload") { plugins.reload() }
                Spacer()
            }
        }
    }
}
