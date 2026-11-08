import CoreLocation
import Foundation
import Observation
import SolarEngine
import GoldenHourCore
import WeatherKit

/// Hourly forecasts from Apple WeatherKit.
///
/// WeatherKit is included in the Apple Developer Program (500,000 calls per month) and is called
/// directly from the device: no server and no third-party key. It needs the WeatherKit capability on the
/// App ID and the `com.apple.developer.weatherkit` entitlement. Apple requires the "Apple Weather"
/// mark and a link to its legal page wherever the data is shown (`attribution`).
///
/// Forecasts are cached per place and hour range for 30 minutes, so scrolling through days or
/// switching tabs does not spend calls; the dashboard asks again when the app becomes active.
@MainActor
@Observable
final class WeatherProvider {
    enum State: Equatable {
        case idle
        case loading
        case loaded(samples: [WeatherSample], fetchedAt: Date)
        case failed(String)
    }

    struct Attribution: Equatable {
        let lightMarkURL: URL
        let darkMarkURL: URL
        let legalPageURL: URL
    }

    private(set) var state: State = .idle
    private(set) var attribution: Attribution?

    @ObservationIgnored private var cache: [String: (samples: [WeatherSample], fetchedAt: Date)] = [:]
    @ObservationIgnored private var currentKey: String?
    private static let maxAge: TimeInterval = 30 * 60

    /// Loads the hourly forecast covering `interval` at `coordinate`, using the cache when it is fresh.
    func load(interval: DateInterval, coordinate: GeoCoordinate, force: Bool = false) async {
        let now = Date.now
        let start = max(interval.start, now.addingTimeInterval(-3600))
        let end = min(interval.end, now.addingTimeInterval(WeatherForecast.horizon))
        guard end > start else {
            state = .idle
            return
        }
        let key = Self.key(coordinate: coordinate, start: start, end: end)
        currentKey = key
        if !force, let cached = cache[key], now.timeIntervalSince(cached.fetchedAt) < Self.maxAge {
            state = .loaded(samples: cached.samples, fetchedAt: cached.fetchedAt)
            return
        }
        if case .loaded = state {} else { state = .loading }
        do {
            let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            let forecast = try await WeatherService.shared.weather(
                for: location, including: .hourly(startDate: start, endDate: end)
            )
            let samples = forecast.forecast.map(Self.sample)
            cache[key] = (samples, .now)
            if currentKey == key { state = .loaded(samples: samples, fetchedAt: .now) }
            await loadAttributionIfNeeded()
        } catch {
            if currentKey == key { state = .failed(Self.message(for: error)) }
        }
    }

    private func loadAttributionIfNeeded() async {
        guard attribution == nil, let value = try? await WeatherService.shared.attribution else { return }
        attribution = Attribution(
            lightMarkURL: value.combinedMarkLightURL,
            darkMarkURL: value.combinedMarkDarkURL,
            legalPageURL: value.legalPageURL
        )
    }

    private static func sample(_ hour: HourWeather) -> WeatherSample {
        WeatherSample(
            date: hour.date,
            cloudCover: hour.cloudCover,
            precipitationChance: hour.precipitationChance,
            temperatureCelsius: hour.temperature.converted(to: .celsius).value,
            visibilityMeters: hour.visibility.converted(to: .meters).value,
            symbolName: hour.symbolName,
            conditionDescription: hour.condition.description
        )
    }

    private static func key(coordinate: GeoCoordinate, start: Date, end: Date) -> String {
        // ~1 km grid and whole hours: nearby requests share the cache.
        let lat = (coordinate.latitude * 100).rounded() / 100
        let lon = (coordinate.longitude * 100).rounded() / 100
        return "\(lat),\(lon),\(Int(start.timeIntervalSince1970 / 3600)),\(Int(end.timeIntervalSince1970 / 3600))"
    }

    private static func message(for error: Error) -> String {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "Météo indisponible sans connexion. Les heures du soleil restent calculées hors ligne."
        }
        return "Météo indisponible pour le moment. Les heures du soleil ne sont pas concernées."
    }
}
