import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var mediaKeys: MediaKeyInterceptor
    @ObservedObject var plugins: PluginRegistry
    @ObservedObject var divider: MenuBarDivider
    @State private var pane = Pane.general

    enum Pane: String, CaseIterable, Identifiable {
        case general, builtIn, plugins, layout, menuBar, huds, appearance, interaction, about

        var id: String { rawValue }

        var title: String {
            switch self {
            case .general: "General"
            case .builtIn: "Built in"
            case .plugins: "Plugins"
            case .layout: "Layout"
            case .menuBar: "Menu bar"
            case .huds: "Overlays"
            case .appearance: "Appearance"
            case .interaction: "Interaction"
            case .about: "About"
            }
        }

        var symbol: String {
            switch self {
            case .general: "gearshape.fill"
            case .builtIn: "square.grid.2x2.fill"
            case .plugins: "puzzlepiece.extension.fill"
            case .layout: "rectangle.split.2x1.fill"
            case .menuBar: "menubar.rectangle"
            case .huds: "rectangle.topthird.inset.filled"
            case .appearance: "paintbrush.fill"
            case .interaction: "hand.point.up.left.fill"
            case .about: "info.circle.fill"
            }
        }

        var tint: Color {
            switch self {
            case .general: .gray
            case .builtIn: .blue
            case .plugins: .purple
            case .layout: .teal
            case .menuBar: .indigo
            case .huds: .orange
            case .appearance: .pink
            case .interaction: .green
            case .about: .gray
            }
        }
    }

    var body: some View {
        NavigationSplitView(columnVisibility: .constant(.all)) {
            sidebar
                .navigationSplitViewColumnWidth(min: 200, ideal: 200, max: 200)
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
        .frame(minWidth: 820, idealWidth: 920, minHeight: 560, idealHeight: 680)
    }

    @ViewBuilder
    private var sidebar: some View {
        if #available(macOS 26, *) {
            GlassSidebar(selection: $pane)
        } else {
            List(Pane.allCases, selection: $pane) { pane in
                PaneLabel(pane: pane)
                    .padding(.vertical, 5)
                    .padding(.leading, 2)
                    .tag(pane)
            }
            .listStyle(.sidebar)
            .safeAreaPadding(.top, 6)
        }
    }

    /// The layout pane is not a Form: its rows reload on every height change, which flashes the tiles.
    @ViewBuilder
    private var paneContent: some View {
        if pane == .layout {
            LayoutPane(preferences: preferences, plugins: plugins)
        } else {
            Form {
                switch pane {
                case .general: GeneralPane(preferences: preferences, mediaKeys: mediaKeys)
                case .builtIn: BuiltInPane(preferences: preferences)
                case .plugins: PluginsPane(plugins: plugins)
                case .menuBar: MenuBarPane(preferences: preferences, divider: divider)
                case .huds: OverlaysPane(preferences: preferences)
                case .appearance: AppearancePane(preferences: preferences)
                case .interaction: InteractionPane(preferences: preferences)
                default: AboutPane()
                }
            }
            .formStyle(.grouped)
        }
    }
}

private struct PaneLabel: View {
    let pane: SettingsView.Pane

    var body: some View {
        HStack(spacing: 10) {
            SettingsIcon(symbol: pane.symbol, tint: pane.tint)
            Text(pane.title)
        }
    }
}

@available(macOS 26, *)
private struct GlassSidebar: View {
    @Binding var selection: SettingsView.Pane

    private static let rowHeight: CGFloat = 36
    private static let spacing: CGFloat = 2

    var body: some View {
        let index = CGFloat(SettingsView.Pane.allCases.firstIndex(of: selection) ?? 0)
        ScrollView {
            ZStack(alignment: .top) {
                Capsule()
                    .fill(.clear)
                    .glassEffect(.regular.interactive(), in: Capsule())
                    .frame(height: Self.rowHeight)
                    .offset(y: index * (Self.rowHeight + Self.spacing))
                    .animation(.smooth(duration: 0.3), value: selection)
                VStack(spacing: Self.spacing) {
                    ForEach(SettingsView.Pane.allCases) { pane in
                        Button {
                            selection = pane
                        } label: {
                            PaneLabel(pane: pane)
                                .padding(.horizontal, 8)
                                .frame(maxWidth: .infinity, minHeight: Self.rowHeight, maxHeight: Self.rowHeight, alignment: .leading)
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.top, 6)
        }
        .scrollIndicators(.never)
    }
}
