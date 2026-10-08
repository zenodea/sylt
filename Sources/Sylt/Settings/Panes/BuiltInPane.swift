import SwiftUI

struct BuiltInPane: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject private var firefoxAccess = FirefoxAccess.shared

    var body: some View {
        Section {
            ForEach(Plugin.allCases) { plugin in
                Toggle(isOn: preferences.binding(for: plugin)) {
                    HStack(spacing: 12) {
                        SettingsIcon(symbol: plugin.symbol, tint: plugin.tint, size: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plugin.title)
                            Text(plugin.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding(.vertical, 4)
            }
        }
        if preferences.isEnabled(.nowPlaying), firefoxAccess.isDenied {
            Section {
                LabeledContent {
                    Button("Open System Settings", action: FirefoxAccess.openPrivacySettings)
                } label: {
                    Text("Firefox artwork")
                    Text("Needs Full Disk Access")
                }
            }
        }
    }
}
