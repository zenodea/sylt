import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var mediaKeys: MediaKeyInterceptor
    @ObservedObject var plugins: PluginRegistry
    @State private var pane = Pane.general
    @State private var opensAtLogin = LoginItem.isEnabled
    @ObservedObject private var firefoxAccess = FirefoxAccess.shared

    enum Pane: String, CaseIterable, Identifiable {
        case general, builtIn, plugins, layout, huds, effects, about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: "General"
            case .builtIn: "Built in"
            case .plugins: "Plugins"
            case .layout: "Layout"
            case .huds: "Overlays"
            case .effects: "Effects"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape.fill"
            case .builtIn: "square.grid.2x2.fill"
            case .plugins: "puzzlepiece.extension.fill"
            case .layout: "rectangle.split.2x1.fill"
            case .huds: "rectangle.topthird.inset.filled"
            case .effects: "sparkles"
            case .about: "info.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .general: .gray
            case .builtIn: .blue
            case .plugins: .purple
            case .layout: .teal
            case .huds: .orange
            case .effects: .pink
            case .about: .gray
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            List(Pane.allCases, selection: $pane) { pane in
                HStack(spacing: 10) {
                    SettingsIcon(symbol: pane.symbol, tint: pane.tint)
                    Text(pane.title)
                }
                .padding(.vertical, 3)
                .padding(.leading, 2)
                .tag(pane)
            }
            .listStyle(.sidebar)
            .safeAreaPadding(.top, 6)
            .navigationSplitViewColumnWidth(min: 190, ideal: 190, max: 190)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                Text(pane.title)
                    .font(.system(size: 22, weight: .bold))
                    .padding(.horizontal, 24)
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                paneContent
            }
            .navigationTitle(pane.title)
        }
        .frame(minWidth: 760, idealWidth: 760, minHeight: 520, idealHeight: 540)
    }

    @ViewBuilder
    private var paneContent: some View {
            Group {
                if pane == .layout {
                    // Not a Form: its rows reload on every height change, which flashes the tiles.
                    LayoutPane(preferences: preferences, plugins: plugins)
                } else {
                    Form {
                        switch pane {
                        case .general: general
                        case .builtIn: builtInPane
                        case .plugins: pluginsPane
                        case .huds: huds
                        case .effects: effects
                        default: about
                        }
                    }
                    .formStyle(.grouped)
                }
            }
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
                HStack(spacing: 10) {
                    if mediaKeys.isAuthorized {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        Label("Not granted", systemImage: "xmark.circle.fill").foregroundStyle(.orange)
                        Button("Open System Settings", action: MediaKeyInterceptor.openAccessibilitySettings)
                    }
                }
            }
            LabeledContent("Key interception") {
                if mediaKeys.isIntercepting {
                    Label("Active", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                } else {
                    Label(preferences.replacesSystemOverlays ? "Waiting for Accessibility" : "Off", systemImage: "circle")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("System overlays")
        }
        .onReceive(Timer.publish(every: 1, on: .main, in: .common).autoconnect()) { _ in mediaKeys.refreshAuthorization() }
        .onAppear { mediaKeys.refreshAuthorization() }
        Section("Lock screen") {
            Toggle("Play a sound when the Mac locks", isOn: $preferences.playsLockSound)
            Toggle("Play a sound when the Mac unlocks", isOn: $preferences.playsUnlockSound)
            Toggle("Keep the wings while locked", isOn: $preferences.lockShowsStatus)
        }
    }

    @ViewBuilder
    private var effects: some View {
        Section {
            Toggle("Take the pointer in", isOn: $preferences.absorbsPointer)
            if preferences.absorbsPointer {
                Toggle("Hold it until pushed", isOn: $preferences.holdsPointer)
                if preferences.holdsPointer {
                    Slider(value: $preferences.releaseForce, in: 0.4...2, step: 0.2) {
                        Text("Push needed")
                    } minimumValueLabel: {
                        Image(systemName: "hand.point.up.left").imageScale(.small)
                    } maximumValueLabel: {
                        Image(systemName: "hand.point.up.left.fill").imageScale(.large)
                    }
                    Toggle("Glow at the edge where it would come out", isOn: $preferences.showsRimGlow)
                }
            }
        } header: {
            Text("Pointer")
        }
        Section("Swipes") {
            Toggle("Lean with swipes", isOn: $preferences.leansWithSwipes)
            if preferences.leansWithSwipes {
                Slider(value: $preferences.swipeLeanStrength, in: 0.25...2, step: 0.25) {
                    Text("How far")
                } minimumValueLabel: {
                    Image(systemName: "arrow.left.and.right").imageScale(.small)
                } maximumValueLabel: {
                    Image(systemName: "arrow.left.and.right").imageScale(.large)
                }
            }
        }
        if preferences.absorbsPointer {
            Section("Letting go") {
                Picker("Effect", selection: $preferences.releaseEffect) {
                    ForEach(ReleaseEffect.allCases) { Text($0.title).tag($0) }
                }
                if preferences.releaseEffect == .ripple {
                    Slider(value: $preferences.rippleStrength, in: 0.5...2.5, step: 0.25) {
                        Text("Ripple strength")
                    } minimumValueLabel: {
                        Image(systemName: "water.waves").imageScale(.small)
                    } maximumValueLabel: {
                        Image(systemName: "water.waves").imageScale(.large)
                    }
                    Slider(value: $preferences.rippleWidth, in: 0.5...3, step: 0.25) {
                        Text("Ripple width")
                    } minimumValueLabel: {
                        Image(systemName: "arrow.left.and.right").imageScale(.small)
                    } maximumValueLabel: {
                        Image(systemName: "arrow.left.and.right").imageScale(.large)
                    }
                }
                Toggle("Haptic tap", isOn: $preferences.hapticsOnRelease)
            }
        }
    }

    @ViewBuilder
    private var builtInPane: some View {
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

    private var pluginsPane: some View {
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
            Text("Overlays")
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
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 96, height: 96)
                Text("Sylt")
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                Text("Version \(Bundle.main.shortVersion)")
                    .foregroundStyle(.secondary)
                Button("Quit Sylt") { NSApp.terminate(nil) }
                    .padding(.top, 6)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }
}

private extension Bundle {
    var shortVersion: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"
    }
}

/// An external plugin: its switch, and its settings when it declares any.
private struct ExternalPluginRow: View {
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
                if expanded {
                    VStack(spacing: 0) {
                        OptionRow(title: "Show overlays") {
                            Toggle("", isOn: Binding(get: { registry.store.showsHUDs(plugin.manifest) }, set: { registry.setShowsHUDs($0, plugin) }))
                                .labelsHidden()
                                .toggleStyle(.switch)
                                .controlSize(.small)
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
        }
        .padding(.vertical, 2)
    }
}

/// One field of a plugin's settings, typed by its manifest.
private struct PluginSettingField: View {
    let setting: PluginManifest.Setting
    let plugin: ExternalPlugin
    @ObservedObject var store: PluginStore

    private var value: JSONValue { store.values(for: plugin.manifest)[setting.key] ?? .null }

    private func set(_ value: JSONValue) {
        store.set(value, for: setting.key, in: plugin.manifest)
        plugin.settingsChanged()
    }

    var body: some View {
        switch setting.type {
        case .bool:
            Toggle("", isOn: Binding(get: { value.boolValue ?? false }, set: { set(.bool($0)) }))
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        case .text:
            TextField("", text: Binding(get: { value.stringValue ?? "" }, set: { set(.string($0)) }), prompt: Text(setting.default?.stringValue ?? ""))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(width: 180)
        case .number:
            HStack(spacing: 6) {
                TextField("", value: Binding(get: { value.doubleValue ?? 0 }, set: { set(.number($0)) }), format: .number)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                Stepper("", value: Binding(get: { value.doubleValue ?? 0 }, set: { set(.number($0)) }), step: 1)
                    .labelsHidden()
                    .controlSize(.small)
            }
        case .choice:
            Picker("", selection: Binding(get: { value.stringValue ?? setting.options?.first ?? "" }, set: { set(.string($0)) })) {
                ForEach(setting.options ?? [], id: \.self) { Text($0) }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 160)
        }
    }
}

/// A symbol on a coloured rounded square, the way System Settings marks every row.
struct SettingsIcon: View {
    let symbol: String
    let tint: Color
    var size: CGFloat = 22

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.75)], startPoint: .top, endPoint: .bottom),
                in: RoundedRectangle(cornerRadius: size * 0.26, style: .continuous)
            )
            .overlay(RoundedRectangle(cornerRadius: size * 0.26, style: .continuous).strokeBorder(.white.opacity(0.18), lineWidth: 0.5))
    }
}

/// One line inside a plugin's options box: the title on the left, its control on the right.
private struct OptionRow<Control: View>: View {
    let title: String
    @ViewBuilder let control: Control

    var body: some View {
        HStack {
            Text(title).font(.callout)
            Spacer()
            control
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

/// A grouped-form look for content that lives outside a Form.
struct SettingsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .padding(.leading, 2)
            content
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor).opacity(0.6), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Color(nsColor: .separatorColor), lineWidth: 1))
        }
    }
}
