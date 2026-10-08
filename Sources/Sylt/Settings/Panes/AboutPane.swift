import SwiftUI

struct AboutPane: View {
    var body: some View {
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
