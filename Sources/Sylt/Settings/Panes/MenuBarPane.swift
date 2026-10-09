import SwiftUI

struct MenuBarPane: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var divider: MenuBarDivider
    @State private var hiding = MenuBarSettings.hiding
    @State private var position: Double = 0
    @State private var shown = Dictionary(uniqueKeysWithValues: MenuBarSettings.items.map { ($0.id, MenuBarSettings.isShown($0)) })

    var body: some View {
        Section("Menu bar") {
            Picker("Hide the menu bar", selection: $hiding) {
                ForEach(MenuBarSettings.Hiding.allCases) { Text($0.title).tag($0) }
            }
            .onChange(of: hiding) { _, value in MenuBarSettings.setHiding(value) }
        }
        Section("Divider") {
            Toggle("Hide the items left of the divider", isOn: $preferences.hidesMenuBarItems)
            Toggle("Show them while the pointer is in the menu bar", isOn: $preferences.revealsMenuBarItems)
                .disabled(!preferences.hidesMenuBarItems)
            LabeledContent("Right now") {
                Button(divider.isHiding ? "Show" : "Hide") { divider.hide(!divider.isHiding) }
                    .disabled(!divider.isActive)
            }
            Slider(value: $position, in: 40...600, step: 10) {
                Text("Position")
            } minimumValueLabel: {
                Image(systemName: "arrow.right.to.line").imageScale(.small)
            } maximumValueLabel: {
                Image(systemName: "arrow.left.to.line").imageScale(.small)
            } onEditingChanged: { editing in
                if !editing { divider.move(to: position) }
            }
            .disabled(!preferences.hidesMenuBarItems)
            .onAppear { position = divider.position }
            Text("Everything left of the divider hides. Move it with the slider, or Command-drag the chevron.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        Section("System items") {
            ForEach(MenuBarSettings.items) { item in
                Toggle(isOn: Binding(
                    get: { shown[item.id] ?? item.shownByDefault },
                    set: { value in
                        shown[item.id] = value
                        MenuBarSettings.setShown(item, value)
                    }
                )) {
                    Label(item.title, systemImage: item.symbol)
                }
                .toggleStyle(.switch)
            }
        }
    }
}
