import XCTest
import SolarEngine
@testable import GoldenHourCore

final class WeatherForecastTests: XCTestCase {
    private func sample(_ hourOffset: Int, from base: Date, cloud: Double = 0.5) -> WeatherSample {
        WeatherSample(date: base.addingTimeInterval(Double(hourOffset) * 3600), cloudCover: cloud,
                      precipitationChance: 0, temperatureCelsius: 12, visibilityMeters: nil,
                      symbolName: "cloud", conditionDescription: "Nuageux")
    }

    func testSamplesOverlappingAPeriod() {
        let base = Date(timeIntervalSince1970: TimeInterval(1_800_000_000 / 3600 * 3600)) // on the hour
        let samples = (0..<24).map { sample($0, from: base) }
        // 18:17 → 19:20 relative to base hours: overlaps hours 18 and 19.
        let period = DateInterval(start: base.addingTimeInterval(18 * 3600 + 17 * 60),
                                  end: base.addingTimeInterval(19 * 3600 + 20 * 60))
        let selected = WeatherForecast.samples(overlapping: period, in: samples.shuffled())
        XCTAssertEqual(selected.map(\.date), [18, 19].map { base.addingTimeInterval(Double($0) * 3600) })
        // A period exactly on hour boundaries does not pull in the neighbouring hours.
        let exact = DateInterval(start: base.addingTimeInterval(5 * 3600), end: base.addingTimeInterval(6 * 3600))
        XCTAssertEqual(WeatherForecast.samples(overlapping: exact, in: samples).count, 1)
        XCTAssertTrue(WeatherForecast.samples(overlapping: period, in: []).isEmpty)
    }

    func testForecastableWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        XCTAssertTrue(WeatherForecast.isForecastable(DateInterval(start: now.addingTimeInterval(3600), duration: 3600), now: now))
        XCTAssertTrue(WeatherForecast.isForecastable(DateInterval(start: now.addingTimeInterval(-600), duration: 3600), now: now),
                      "a period in progress is still forecastable")
        XCTAssertFalse(WeatherForecast.isForecastable(DateInterval(start: now.addingTimeInterval(-7200), duration: 3600), now: now))
        XCTAssertFalse(WeatherForecast.isForecastable(DateInterval(start: now.addingTimeInterval(11 * 86_400), duration: 3600), now: now))
    }

    func testRequestIntervalCoversPeriodsOutsideTheDay() {
        let zone = TimeZone(identifier: "Europe/Oslo")!
        let tromso = GeoCoordinate(latitude: 69.6492, longitude: 18.9553)!
        let day = SolarDayCalculator.solarDay(for: LocalDate(year: 2026, month: 2, day: 5)!, coordinate: tromso, timeZone: zone)
        let interval = WeatherForecast.requestInterval(for: day)
        XCTAssertLessThanOrEqual(interval.start, day.interval.start)
        XCTAssertGreaterThanOrEqual(interval.end, day.interval.end)
        for period in day.goldenHours + day.blueHours {
            XCTAssertLessThanOrEqual(interval.start, period.start)
            XCTAssertGreaterThanOrEqual(interval.end, period.end)
        }
    }
}
