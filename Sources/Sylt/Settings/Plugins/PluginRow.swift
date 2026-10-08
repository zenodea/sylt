import SwiftUI

/// An external plugin: its switch, and its options when it is on.
struct ExternalPluginRow: View {
    @ObservedObject var plugin: ExternalPlugin
    @ObservedObject var registry: PluginRegistry
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: Binding(get: { registry.isEnabled(plugin) }, set: { registry.setEnabled($0, plugin) })) {
                HStack(spacing: 12) {
                    SettingsIcon(symbol: plugin.manifest.symbol ?? "puzzlepiece.extension.fill", tint: plugin.isBundled ? .indigo : .purple, size: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(plugin.manifest.name)
                            if !plugin.isBundled {
                                Text("Yours").font(.caption2).padding(.horizontal, 5).padding(.vertical, 1)
                                    .background(.purple.opacity(0.25), in: Capsule())
                            }
                        }
                        if let description = plugin.manifest.description {
                            Text(description).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .toggleStyle(.switch)
            if registry.isEnabled(plugin) {
                Button {
                    withAnimation(.easeOut(duration: 0.18)) { expanded.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .rotationEffect(.degrees(expanded ? 90 : 0))
                        Text("Options")
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 40)
                if expanded { options }
            }
        }
        .padding(.vertical, 2)
    }

    private var options: some View {
        VStack(spacing: 0) {
            OptionRow(title: "Show overlays") {
                OptionSwitch(isOn: Binding(get: { registry.store.showsHUDs(plugin.manifest) }, set: { registry.setShowsHUDs($0, plugin) }))
            }
            ForEach(plugin.manifest.settings ?? []) { setting in
                Divider().padding(.leading, 12)
                OptionRow(title: setting.title) {
                    PluginSettingField(setting: setting, plugin: plugin, store: registry.store)
                }
            }
        }
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(.quaternary, lineWidth: 1))
        .padding(.leading, 40)
        .padding(.top, 2)
        .transition(.opacity)
    }
}
