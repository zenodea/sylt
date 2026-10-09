import SwiftUI

struct GeneralPane: View {
    @ObservedObject var preferences: Preferences
    @ObservedObject var mediaKeys: MediaKeyInterceptor
    @State private var opensAtLogin = LoginItem.isEnabled

    var body: some View {
        Section("Island") {
            Slider(value: $preferences.notchDepth, in: 0...8, step: 1) {
                Text("Depth below the notch")
            } minimumValueLabel: {
                Image(systemName: "rectangle.topthird.inset.filled").imageScale(.small)
            } maximumValueLabel: {
                Image(systemName: "rectangle.topthird.inset.filled").imageScale(.large)
            }
            Toggle("Open pages side by side when the screen has room", isOn: $preferences.spreadsPages)
        }
        Section("Startup") {
            Toggle("Open at login", isOn: Binding(
                get: { opensAtLogin },
                set: { enabled in
                    try? LoginItem.set(enabled)
                    opensAtLogin = LoginItem.isEnabled
                }
            ))
        }
        Section("System overlays") {
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
        }
        .task {
            while !Task.isCancelled {
                mediaKeys.refreshAuthorization()
                try? await Task.sleep(for: .seconds(1))
            }
        }
        Section("Lock screen") {
            Toggle("Play a sound when the Mac locks", isOn: $preferences.playsLockSound)
            Toggle("Play a sound when the Mac unlocks", isOn: $preferences.playsUnlockSound)
            Toggle("Keep the wings while locked", isOn: $preferences.lockShowsStatus)
        }
    }
}
