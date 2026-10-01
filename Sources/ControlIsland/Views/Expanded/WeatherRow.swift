import SwiftUI

struct WeatherRow: View {
    let report: WeatherMonitor.Report

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: report.symbol)
                .font(.system(size: 18))
                .symbolRenderingMode(.multicolor)
                .frame(width: 24)
            Text("\(Int(report.temperature.rounded()))°")
                .font(.system(size: 16, weight: .semibold, design: .rounded))
                .monospacedDigit()
            Text(report.summary).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text("H \(Int(report.high.rounded()))°  L \(Int(report.low.rounded()))°")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .monospacedDigit()
            if !report.place.isEmpty {
                Text(report.place)
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: IslandLayout.weatherRowHeight)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 10))
    }
}
