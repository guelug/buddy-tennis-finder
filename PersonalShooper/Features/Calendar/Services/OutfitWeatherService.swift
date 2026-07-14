import Foundation
import CoreLocation
import MapKit

/// One day's forecast used in the outfit calendar.
struct DayForecast: Identifiable, Sendable {
    let date: Date
    let tempMax: Double
    let tempMin: Double
    let code: Int

    var id: Date { date }

    /// SF Symbol for the WMO weather code.
    var symbolName: String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55, 56, 57: return "cloud.drizzle.fill"
        case 61, 63, 65, 66, 67, 80, 81, 82: return "cloud.rain.fill"
        case 71, 73, 75, 77, 85, 86: return "cloud.snow.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    func description(spanish: Bool) -> String {
        switch code {
        case 0: return spanish ? "Despejado" : "Clear"
        case 1, 2: return spanish ? "Parcialmente nublado" : "Partly cloudy"
        case 3: return spanish ? "Nublado" : "Cloudy"
        case 45, 48: return spanish ? "Niebla" : "Fog"
        case 51, 53, 55, 56, 57: return spanish ? "Llovizna" : "Drizzle"
        case 61, 63, 65, 66, 67, 80, 81, 82: return spanish ? "Lluvia" : "Rain"
        case 71, 73, 75, 77, 85, 86: return spanish ? "Nieve" : "Snow"
        case 95, 96, 99: return spanish ? "Tormenta" : "Storm"
        default: return spanish ? "Variable" : "Mixed"
        }
    }
}

/// Fetches a multi-day forecast from the free Open-Meteo API (no key, no entitlement) for the
/// user's current location. Falls back silently to no data if location/network is unavailable.
@MainActor
final class OutfitWeatherService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var locationContinuation: CheckedContinuation<CLLocation?, Never>?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    var placeName: String?

    func forecast(days: Int) async -> [DayForecast] {
        guard let location = await currentLocation() else { return [] }
        await reverseGeocode(location)
        return await fetchForecast(latitude: location.coordinate.latitude,
                                   longitude: location.coordinate.longitude,
                                   days: days)
    }

    // MARK: - Location

    private func currentLocation() async -> CLLocation? {
        let status = manager.authorizationStatus
        if status == .notDetermined {
            manager.requestWhenInUseAuthorization()
        }
        if status == .denied || status == .restricted { return nil }

        return await withCheckedContinuation { continuation in
            locationContinuation = continuation
            manager.requestLocation()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let location = locations.last
        Task { @MainActor in
            self.locationContinuation?.resume(returning: location)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        Task { @MainActor in
            self.locationContinuation?.resume(returning: nil)
            self.locationContinuation = nil
        }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        // No-op: forecast() drives the request flow directly.
    }

    private func reverseGeocode(_ location: CLLocation) async {
        if #available(iOS 26.0, *) {
            guard let request = MKReverseGeocodingRequest(location: location),
                  let mapItems = try? await request.mapItems,
                  let address = mapItems.first?.address else { return }
            placeName = address.shortAddress ?? address.fullAddress
        } else {
            guard let placemark = try? await CLGeocoder().reverseGeocodeLocation(location).first else { return }
            placeName = placemark.locality ?? placemark.subAdministrativeArea ?? placemark.name
        }
    }

    // MARK: - Forecast

    private func fetchForecast(latitude: Double, longitude: Double, days: Int) async -> [DayForecast] {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "daily", value: "temperature_2m_max,temperature_2m_min,weather_code"),
            URLQueryItem(name: "forecast_days", value: String(min(max(days, 1), 16))),
            URLQueryItem(name: "timezone", value: "auto")
        ]
        guard let url = components.url else { return [] }

        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let decoded = try? JSONDecoder().decode(OpenMeteoResponse.self, from: data) else {
            return []
        }

        let daily = decoded.daily
        let parser = DateFormatter()
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.dateFormat = "yyyy-MM-dd"

        var result: [DayForecast] = []
        for (index, dayString) in daily.time.enumerated() {
            guard index < daily.temperature_2m_max.count,
                  index < daily.temperature_2m_min.count,
                  index < daily.weather_code.count,
                  let date = parser.date(from: dayString) else { continue }
            result.append(DayForecast(
                date: date,
                tempMax: daily.temperature_2m_max[index],
                tempMin: daily.temperature_2m_min[index],
                code: daily.weather_code[index]
            ))
        }
        return result
    }
}

private struct OpenMeteoResponse: Decodable {
    let daily: Daily
    struct Daily: Decodable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let weather_code: [Int]
    }
}
