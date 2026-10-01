import SwiftUI

struct WeatherBadge: View {
    let report: WeatherMonitor.Report

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: report.symbol)
                .font(.system(size: 11, weight: .semibold))
                .symbolRenderingMode(.multicolor)
            Text("\(Int(report.temperature.rounded()))°")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
        }
        .foregroundStyle(.white.opacity(0.85))
    }
}
