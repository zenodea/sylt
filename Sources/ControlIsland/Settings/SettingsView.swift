import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var mediaKeys: MediaKeyInterceptor
    @State private var pane = Pane.general
    @State private var opensAtLogin = LoginItem.isEnabled

    enum Pane: String, CaseIterable, Identifiable {
        case general, plugins, huds, about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: "General"
            case .plugins: "Plugins"
            case .huds: "Overlays"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape.fill"
            case .plugins: "puzzlepiece.extension.fill"
            case .huds: "rectangle.topthird.inset.filled"
            case .about: "info.circle.fill"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            List(Pane.allCases, selection: $pane) { pane in
                Label(pane.title, systemImage: pane.symbol).tag(pane)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(168)
        } detail: {
            Form {
                switch pane {
                case .general: general
                case .plugins: plugins
                case .huds: huds
                case .about: about
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 700, height: 480)
    }

    @ViewBuilder
    private var general: some View {
        Section("Startup") {
            Toggle("Open at login", isOn: Binding(
                get: { opensAtLogin },
                set: { enabled in
                    try? LoginItem.set(enabled)
                    opensAtLogin = LoginItem.isEnabled
                }
            ))
        }
        Section {
            Toggle("Replace the macOS volume and brightness overlays", isOn: $preferences.replacesSystemOverlays)
                .disabled(!preferences.isEnabled(.volume) && !preferences.isEnabled(.brightness))
            LabeledContent("Accessibility") {
                if mediaKeys.isAuthorized {
                    Label("Granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Button("Open System Settings", action: MediaKeyInterceptor.openAccessibilitySettings)
                }
            }
        } header: {
            Text("System overlays")
        }
        Section("Unlock") {
            Toggle("Play a sound when the Mac unlocks", isOn: $preferences.playsUnlockSound)
        }
    }

    private var plugins: some View {
        Section {
            ForEach(Plugin.allCases) { plugin in
                Toggle(isOn: preferences.binding(for: plugin)) {
                    HStack(spacing: 12) {
                        Image(systemName: plugin.symbol)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
                            .background(.tint, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(plugin.title)
                            Text(plugin.detail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding(.vertical, 2)
            }
        }
    }

    @ViewBuilder
    private var huds: some View {
        Section {
            ForEach(HUDCategory.allCases) { category in
                Toggle(isOn: preferences.binding(for: category)) {
                    Label(category.title, systemImage: category.symbol)
                }
                .toggleStyle(.switch)
            }
        } header: {
            Text("Show an overlay for")
        }
        Section("Timing") {
            LabeledContent("Overlay duration") {
                HStack(spacing: 10) {
                    Slider(value: $preferences.hudDurationScale, in: 0.6...2.5)
                        .frame(width: 180)
                    Text(String(format: "%.1f×", preferences.hudDurationScale))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .frame(width: 36, alignment: .trailing)
                }
            }
        }
    }

    private var about: some View {
        Section {
            VStack(spacing: 10) {
                IslandMark()
                Text("Control Island")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("Version \(Bundle.main.shortVersion)")
                    .foregroundStyle(.secondary)
                Text("A dynamic island for the notch: media, levels, agents and alerts, drawn where your eyes already are.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                Button("Quit Control Island") { NSApp.terminate(nil) }
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

/// A miniature island, for the About pane.
private struct IslandMark: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(.black)
            .frame(width: 96, height: 30)
            .overlay(alignment: .leading) {
                Circle().fill(.white.opacity(0.85)).frame(width: 8, height: 8).padding(.leading, 12)
            }
            .overlay(alignment: .trailing) {
                AudioBars(isPlaying: true, colors: [.white], height: 12).padding(.trailing, 12)
            }
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
    }
}

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}
