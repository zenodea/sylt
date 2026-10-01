import Combine
import Foundation

/// Current conditions for roughly where the Mac is, from Open-Meteo via IP geolocation.
@MainActor
final class WeatherMonitor: ObservableObject {
    struct Report: Hashable {
        let temperature: Double
        let high: Double
        let low: Double
        let code: Int
        let place: String

        var symbol: String { Self.symbol(for: code) }
        var summary: String { Self.summary(for: code) }

        private static func symbol(for code: Int) -> String {
            switch code {
            case 0: "sun.max.fill"
            case 1, 2: "cloud.sun.fill"
            case 3: "cloud.fill"
            case 45, 48: "cloud.fog.fill"
            case 51...57: "cloud.drizzle.fill"
            case 61...67, 80...82: "cloud.rain.fill"
            case 71...77, 85, 86: "cloud.snow.fill"
            case 95...99: "cloud.bolt.rain.fill"
            default: "cloud.fill"
            }
        }

        private static func summary(for code: Int) -> String {
            switch code {
            case 0: "Clear"
            case 1, 2: "Partly cloudy"
            case 3: "Overcast"
            case 45, 48: "Fog"
            case 51...57: "Drizzle"
            case 61...67, 80...82: "Rain"
            case 71...77, 85, 86: "Snow"
            case 95...99: "Thunderstorm"
            default: "Cloudy"
            }
        }
    }

    @Published private(set) var report: Report?

    private var timer: Timer?
    private var task: Task<Void, Never>?

    func start() {
        guard timer == nil else { return }
        fetch()
        timer = .every(30 * 60) { [weak self] in self?.fetch() }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        task?.cancel()
        report = nil
    }

    private func fetch() {
        task?.cancel()
        task = Task { [weak self] in
            guard let location = await Self.location(), let report = await Self.report(at: location) else { return }
            self?.report = report
        }
    }

    private struct Location { let latitude: Double; let longitude: Double; let city: String }

    private static func location() async -> Location? {
        guard let url = URL(string: "https://ipinfo.io/json"),
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let loc = json["loc"] as? String
        else { return nil }
        let parts = loc.split(separator: ",").compactMap { Double($0) }
        guard parts.count == 2 else { return nil }
        return Location(latitude: parts[0], longitude: parts[1], city: json["city"] as? String ?? "")
    }

    private static func report(at location: Location) async -> Report? {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            .init(name: "latitude", value: "\(location.latitude)"),
            .init(name: "longitude", value: "\(location.longitude)"),
            .init(name: "current", value: "temperature_2m,weather_code"),
            .init(name: "daily", value: "temperature_2m_max,temperature_2m_min"),
            .init(name: "timezone", value: "auto"),
            .init(name: "forecast_days", value: "1"),
        ]
        guard let url = components.url,
              let (data, _) = try? await URLSession.shared.data(from: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let current = json["current"] as? [String: Any],
              let temperature = current["temperature_2m"] as? Double,
              let code = current["weather_code"] as? Int,
              let daily = json["daily"] as? [String: Any],
              let high = (daily["temperature_2m_max"] as? [Double])?.first,
              let low = (daily["temperature_2m_min"] as? [Double])?.first
        else { return nil }
        return Report(temperature: temperature, high: high, low: low, code: code, place: location.city)
    }
}
