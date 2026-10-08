import SwiftUI

/// One field of a plugin's settings, typed by its manifest.
struct PluginSettingField: View {
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
            OptionSwitch(isOn: Binding(get: { value.boolValue ?? false }, set: { set(.bool($0)) }))
        case .text:
            TextField("", text: Binding(get: { value.stringValue ?? "" }, set: { set(.string($0)) }), prompt: Text(setting.default?.stringValue ?? ""))
                .textFieldStyle(.roundedBorder)
                .controlSize(.small)
                .frame(width: 180)
        case .number:
            let number = Binding(get: { value.doubleValue ?? 0 }, set: { set(.number($0)) })
            HStack(spacing: 6) {
                TextField("", value: number, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.small)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 56)
                Stepper("", value: number, step: 1)
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
