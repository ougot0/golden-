import Foundation
import XCTest
@testable import SolarEngine

final class SolarDayTests: XCTestCase {
    let paris = GeoCoordinate(latitude: 48.8566, longitude: 2.3522)!
    let parisZone = TimeZone(identifier: "Europe/Paris")!
    let tromso = GeoCoordinate(latitude: 69.6492, longitude: 18.9553)!
    let osloZone = TimeZone(identifier: "Europe/Oslo")!

    func day(_ y: Int, _ m: Int, _ d: Int, _ c: GeoCoordinate, _ tz: TimeZone) -> SolarDay {
        SolarDayCalculator.solarDay(for: LocalDate(year: y, month: m, day: d)!, coordinate: c, timeZone: tz)
    }

    func testCoordinateValidation() {
        XCTAssertNil(GeoCoordinate(latitude: 91, longitude: 0))
        XCTAssertNil(GeoCoordinate(latitude: 0, longitude: -181))
        XCTAssertNil(GeoCoordinate(latitude: .nan, longitude: 0))
        XCTAssertNotNil(GeoCoordinate(latitude: -90, longitude: 180))
    }

    func testLocalDateValidationAndArithmetic() {
        XCTAssertNil(LocalDate(year: 2026, month: 2, day: 29))
        XCTAssertNotNil(LocalDate(year: 2028, month: 2, day: 29))
        XCTAssertEqual(LocalDate(year: 2026, month: 12, day: 31)!.adding(days: 1), LocalDate(year: 2027, month: 1, day: 1)!)
        XCTAssertEqual(LocalDate(year: 2026, month: 3, day: 1)!.adding(days: -1), LocalDate(year: 2026, month: 2, day: 28)!)
    }

    func testDSTDaysHaveCorrectLength() {
        let spring = LocalDate(year: 2026, month: 3, day: 29)!.interval(in: parisZone)
        let autumn = LocalDate(year: 2026, month: 10, day: 25)!.interval(in: parisZone)
        let normal = LocalDate(year: 2026, month: 6, day: 1)!.interval(in: parisZone)
        XCTAssertEqual(spring.duration, 23 * 3600)
        XCTAssertEqual(autumn.duration, 25 * 3600)
        XCTAssertEqual(normal.duration, 24 * 3600)
    }

    func testEventsAreOrderedForAnOrdinaryDay() throws {
        let d = day(2026, 6, 21, paris, parisZone)
        XCTAssertEqual(d.sunCondition, .normal)
        let expected: [SolarEventKind] = [
            .nauticalDawn, .civilDawn, .morningBlueHourStart, .morningGoldenHourStart, .sunrise,
            .morningGoldenHourEnd, .solarNoon, .eveningGoldenHourStart, .sunset, .eveningGoldenHourEnd,
            .eveningBlueHourEnd, .civilDusk, .nauticalDusk,
        ]
        // Paris at the June solstice has no astronomical night: the Sun stays above −18°.
        XCTAssertNil(d.event(.astronomicalDawn))
        XCTAssertNil(d.event(.astronomicalDusk))
        // With the standard conventions, civil dawn and the start of the blue hour share the −6° threshold.
        let kinds = d.events.map(\.kind).filter { expected.contains($0) }
        XCTAssertEqual(Set(kinds), Set(expected))
        let dates = expected.compactMap { d.event($0)?.date }
        XCTAssertEqual(dates.count, expected.count)
        XCTAssertEqual(dates, dates.sorted())

        let morning = try XCTUnwrap(d.morningGoldenHour)
        XCTAssertEqual(morning.start, d.event(.morningGoldenHourStart)?.date)
        XCTAssertEqual(morning.end, d.event(.morningGoldenHourEnd)?.date)
        let evening = try XCTUnwrap(d.eveningBlueHour)
        XCTAssertEqual(evening.start, d.event(.eveningGoldenHourEnd)?.date)
        XCTAssertEqual(evening.end, d.event(.eveningBlueHourEnd)?.date)
        XCTAssertEqual(d.goldenHours.count, 2)
        XCTAssertEqual(d.blueHours.count, 2)
    }

    func testTimelineCoversTheWholeDayWithoutGaps() {
        for d in [day(2026, 6, 21, paris, parisZone), day(2026, 3, 29, paris, parisZone),
                  day(2026, 12, 21, tromso, osloZone), day(2026, 6, 21, tromso, osloZone)] {
            XCTAssertEqual(d.timeline.first?.interval.start, d.interval.start)
            XCTAssertEqual(d.timeline.last?.interval.end, d.interval.end)
            for (a, b) in zip(d.timeline, d.timeline.dropFirst()) {
                XCTAssertEqual(a.interval.end, b.interval.start)
                XCTAssertNotEqual(a.phase, b.phase)
            }
        }
    }

    func testDaylightDurationParisSolstice() {
        let d = day(2026, 6, 21, paris, parisZone)
        // Reference (Skyfield): 03:46:57Z → 19:57:52Z = 16 h 10 min 55 s.
        XCTAssertEqual(d.daylightDuration, 16 * 3600 + 10 * 60 + 55, accuracy: 30)
    }

    func testPolarNightAndMidnightSun() {
        let winter = day(2026, 12, 21, tromso, osloZone)
        XCTAssertEqual(winter.sunCondition, .alwaysBelow)
        XCTAssertNil(winter.sunrise)
        XCTAssertNil(winter.sunset)
        XCTAssertEqual(winter.daylightDuration, 0)
        XCTAssertLessThan(winter.maximumElevation, SolarThreshold.horizon)
        // The Sun stays in the twilight bands around noon: a single continuous blue hour.
        XCTAssertNotNil(winter.solarNoon)

        let summer = day(2026, 6, 21, tromso, osloZone)
        XCTAssertEqual(summer.sunCondition, .alwaysAbove)
        XCTAssertNil(summer.sunrise)
        XCTAssertNil(summer.sunset)
        XCTAssertEqual(summer.daylightDuration, summer.interval.duration, accuracy: 0.001)
        XCTAssertGreaterThan(summer.minimumElevation, SolarThreshold.horizon)
    }

    func testLowSunDayHasContinuousGoldenHour() throws {
        // Tromsø, 10 January: the Sun stays below the horizon; Longyearbyen in mid-February skims the
        // twilight bands. Look for a day where the Sun peaks inside the golden band.
        let tromsoFeb = day(2026, 2, 5, tromso, osloZone)
        XCTAssertLessThan(tromsoFeb.maximumElevation, 6)
        XCTAssertGreaterThan(tromsoFeb.maximumElevation, -4)
        let golden = try XCTUnwrap(tromsoFeb.goldenHours.first)
        XCTAssertEqual(golden.part, .continuous)
        XCTAssertNil(tromsoFeb.morningGoldenHour)
        XCTAssertNil(tromsoFeb.eveningGoldenHour)
    }

    func testDifferentTimeZoneFromDeviceDoesNotChangeEvents() {
        let tokyo = GeoCoordinate(latitude: 35.6762, longitude: 139.6503)!
        let tokyoZone = TimeZone(identifier: "Asia/Tokyo")!
        let d = day(2026, 9, 23, tokyo, tokyoZone)
        let sunrise = d.sunrise!
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = tokyoZone
        let c = calendar.dateComponents([.year, .month, .day, .hour], from: sunrise)
        XCTAssertEqual(c.day, 23)
        XCTAssertEqual(c.hour, 5)
    }

    func testSolarPositionAtSolarNoonIsSouthInNorthernHemisphere() {
        let d = day(2026, 3, 20, paris, parisZone)
        let p = SolarCalculator.position(at: d.solarNoon!, coordinate: paris)
        XCTAssertEqual(p.azimuth, 180, accuracy: 0.05)
        XCTAssertEqual(p.hourAngle, 0, accuracy: 0.01)
        // At the equinox the noon elevation is ≈ 90° − latitude.
        XCTAssertEqual(p.elevation, 90 - 48.8566, accuracy: 0.5)
    }

    func testRefraction() {
        XCTAssertEqual(Refraction.standardCorrection(forGeometricElevation: 90), 0, accuracy: 0.001)
        // ≈ 29′ at a geometric elevation of 0° (Meeus, Sæmundsson formula).
        XCTAssertEqual(Refraction.standardCorrection(forGeometricElevation: 0) * 60, 29, accuracy: 1)
        XCTAssertEqual(Refraction.standardCorrection(forGeometricElevation: -5), 0)
    }

    func testLightStatusFindsNextPeriod() throws {
        // Paris, 2026-06-21 at 12:00 local: next period is the evening golden hour.
        let noon = LocalDate(year: 2026, month: 6, day: 21)!.startOfDay(in: parisZone).addingTimeInterval(12 * 3600)
        let status = LightForecast.status(at: noon, coordinate: paris, timeZone: parisZone)
        XCTAssertEqual(status.phase, .daylight)
        XCTAssertNil(status.currentPeriod)
        let next = try XCTUnwrap(status.nextPeriod)
        XCTAssertEqual(next.phase, .goldenHour)
        XCTAssertEqual(next.part, .evening)

        // During the evening golden hour the current period is reported and the next one is the blue hour.
        let during = next.start.addingTimeInterval(60)
        let status2 = LightForecast.status(at: during, coordinate: paris, timeZone: parisZone)
        XCTAssertEqual(status2.currentPeriod?.phase, .goldenHour)
        XCTAssertEqual(status2.nextPeriod?.phase, .blueHour)
    }

    func testLightStatusDuringPolarNightSearchesAhead() {
        let longyearbyen = GeoCoordinate(latitude: 78.2232, longitude: 15.6267)!
        let date = LocalDate(year: 2026, month: 12, day: 21)!.startOfDay(in: osloZone).addingTimeInterval(12 * 3600)
        let status = LightForecast.status(at: date, coordinate: longyearbyen, timeZone: osloZone, maximumDays: 10)
        // At 78°N the Sun stays below −6° around the December solstice: no blue or golden hour for weeks.
        XCTAssertNil(status.nextPeriod)
        XCTAssertEqual(status.searchedDays, 10)
    }

    func testSolarPathSamplesCoverTheDay() {
        let date = LocalDate(year: 2026, month: 6, day: 21)!
        let samples = SolarPath.samples(for: date, coordinate: paris, timeZone: parisZone, step: 3600)
        XCTAssertEqual(samples.count, 25)
        XCTAssertEqual(samples.map(\.elevation).max()!, 64.7, accuracy: 1)
    }
}
