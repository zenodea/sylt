import SwiftUI

struct HeadphonesBadge: View {
    let device: BluetoothMonitor.Device

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: device.name.localizedCaseInsensitiveContains("airpods") ? "airpodspro" : "headphones")
                .font(.system(size: 11, weight: .semibold))
            Text("\(device.battery ?? 0)")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .fixedSize()
        }
        .foregroundStyle((device.battery ?? 100) <= 20 ? Color.red : .white.opacity(0.85))
    }
}
