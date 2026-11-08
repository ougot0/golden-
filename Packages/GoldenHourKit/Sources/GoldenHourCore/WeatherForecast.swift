import Foundation
import SolarEngine

/// One hour of forecast, independent of the weather provider (WeatherKit in the app).
public struct WeatherSample: Hashable, Sendable {
    /// Start of the forecast hour.
    public let date: Date
    /// Fraction of the sky covered by clouds, 0…1.
    public let cloudCover: Double
    /// Probability of precipitation, 0…1.
    public let precipitationChance: Double
    public let temperatureCelsius: Double
    /// Visibility in metres, when the provider gives it.
    public let visibilityMeters: Double?
    /// SF Symbol name for the condition.
    public let symbolName: String
    /// Localised condition description, e.g. "Partiellement nuageux".
    public let conditionDescription: String

    public init(date: Date, cloudCover: Double, precipitationChance: Double, temperatureCelsius: Double,
                visibilityMeters: Double?, symbolName: String, conditionDescription: String) {
        self.date = date
        self.cloudCover = cloudCover
        self.precipitationChance = precipitationChance
        self.temperatureCelsius = temperatureCelsius
        self.visibilityMeters = visibilityMeters
        self.symbolName = symbolName
        self.conditionDescription = conditionDescription
    }
}

public enum WeatherForecast {
    /// Forecast horizon of the provider (WeatherKit: 10 days of hourly data).
    public static let horizon: TimeInterval = 10 * 86_400

    /// Forecast hours that overlap `interval`. Each sample covers [date, date + 1 h).
    public static func samples(overlapping interval: DateInterval, in samples: [WeatherSample]) -> [WeatherSample] {
        samples
            .filter { $0.date < interval.end && $0.date.addingTimeInterval(3600) > interval.start }
            .sorted { $0.date < $1.date }
    }

    /// Whether a forecast can exist for the light period: it must end in the future and start within the horizon.
    public static func isForecastable(_ interval: DateInterval, now: Date) -> Bool {
        interval.end > now && interval.start < now.addingTimeInterval(horizon)
    }

    /// The interval to request from the provider for a local day: the day itself, widened to cover golden and
    /// blue hours whose bounds fall on the previous or next day.
    public static func requestInterval(for day: SolarDay) -> DateInterval {
        let periods = day.goldenHours + day.blueHours
        let start = min(day.interval.start, periods.map(\.start).min() ?? day.interval.start)
        let end = max(day.interval.end, periods.map(\.end).max() ?? day.interval.end)
        return DateInterval(start: start, end: end)
    }
}
