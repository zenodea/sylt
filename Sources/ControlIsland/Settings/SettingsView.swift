import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var mediaKeys: MediaKeyInterceptor

    var body: some View {
        Form {
            Section("Plugins") {
                ForEach(Plugin.allCases) { plugin in
                    Toggle(isOn: preferences.binding(for: plugin)) {
                        Label {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plugin.title)
                                Text(plugin.detail)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: plugin.symbol)
                        }
                    }
                }
            }

            Section("HUDs") {
                ForEach(HUDCategory.allCases) { category in
                    Toggle(category.title, isOn: preferences.binding(for: category))
                }
                HStack {
                    Text("Duration")
                    Slider(value: $preferences.hudDurationScale, in: 0.6...2.5)
                    Text(String(format: "%.1f×", preferences.hudDurationScale))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                }
                Toggle("Play a sound when the Mac unlocks", isOn: $preferences.playsUnlockSound)
            }

            Section {
                Toggle("Replace macOS volume and brightness overlays", isOn: $preferences.replacesSystemOverlays)
                    .disabled(!preferences.isEnabled(.volume) && !preferences.isEnabled(.brightness))
                if preferences.replacesSystemOverlays, !mediaKeys.isAuthorized {
                    HStack {
                        Label("Needs Accessibility access to take over the keys.", systemImage: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Spacer()
                        Button("Open System Settings", action: MediaKeyInterceptor.openAccessibilitySettings)
                    }
                }
            } header: {
                Text("System")
            } footer: {
                Text("The island handles the volume and brightness keys itself, so the built-in overlays never appear.")
            }

            Section {
                HStack {
                    Text("Control Island \(Bundle.main.shortVersion)")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Quit") { NSApp.terminate(nil) }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 440)
    }
}

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
