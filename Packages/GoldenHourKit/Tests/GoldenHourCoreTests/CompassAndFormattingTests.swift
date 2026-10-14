import XCTest
@testable import GoldenHourCore

final class CompassMathTests: XCTestCase {
    func testHeadingReliability() {
        XCTAssertEqual(HeadingReliability(headingAccuracy: nil), .unavailable)
        XCTAssertEqual(HeadingReliability(headingAccuracy: -1), .unavailable)
        XCTAssertEqual(HeadingReliability(headingAccuracy: 5), .good(accuracy: 5))
        XCTAssertEqual(HeadingReliability(headingAccuracy: 20), .approximate(accuracy: 20))
        XCTAssertEqual(HeadingReliability(headingAccuracy: 45), .needsCalibration(accuracy: 45))
        XCTAssertFalse(HeadingReliability(headingAccuracy: 45).allowsLiveOrientation)
        XCTAssertFalse(HeadingReliability.unavailable.allowsLiveOrientation)
        XCTAssertTrue(HeadingReliability(headingAccuracy: 8).allowsLiveOrientation)
    }

    func testAngles() {
        XCTAssertEqual(CompassMath.normalized(-10), 350)
        XCTAssertEqual(CompassMath.normalized(720), 0)
        XCTAssertEqual(CompassMath.signedDelta(from: 350, to: 10), 20)
        XCTAssertEqual(CompassMath.signedDelta(from: 10, to: 350), -20)
        XCTAssertEqual(CompassMath.relativeBearing(target: 270, heading: 0), -90)
        XCTAssertEqual(CompassMath.continuousAngle(previous: 359, next: 1), 361)
        XCTAssertEqual(CompassMath.continuousAngle(previous: -1, next: 358), -2)
    }

    func testCardinals() {
        XCTAssertEqual(CompassMath.cardinalAbbreviation(for: 0), "N")
        XCTAssertEqual(CompassMath.cardinalAbbreviation(for: 359), "N")
        XCTAssertEqual(CompassMath.cardinalAbbreviation(for: 90), "E")
        XCTAssertEqual(CompassMath.cardinalAbbreviation(for: 225), "SO")
        XCTAssertEqual(CompassMath.cardinalAbbreviation(for: 292.5), "ONO")
    }
}

final class FormattingTests: XCTestCase {
    func testDurations() {
        XCTAssertEqual(DurationFormatting.hoursMinutes(16 * 3600 + 10 * 60 + 55), "16 h 11")
        XCTAssertEqual(DurationFormatting.hoursMinutes(42 * 60), "42 min")
        XCTAssertEqual(DurationFormatting.hoursMinutes(0), "0 min")
        XCTAssertEqual(DurationFormatting.countdown(3600 * 2 + 5 * 60 + 9), "2:05:09")
        XCTAssertEqual(DurationFormatting.countdown(249.2), "4:10")
        XCTAssertEqual(DurationFormatting.countdown(-5), "0:00")
    }

    func testTimesUseThePlaceTimeZone() {
        // 2026-06-21T19:57:52Z = 21:57 in Paris, 04:57 (+1 day) in Tokyo.
        let date = Date(timeIntervalSince1970: 1_782_071_872)
        let paris = SolarTimeFormatter(timeZone: TimeZone(identifier: "Europe/Paris")!, hourCycle: .twentyFourHour,
                                       locale: Locale(identifier: "fr_FR"))
        XCTAssertEqual(paris.time(date), "21:57")
        let tokyo = SolarTimeFormatter(timeZone: TimeZone(identifier: "Asia/Tokyo")!, hourCycle: .twentyFourHour,
                                       locale: Locale(identifier: "fr_FR"))
        XCTAssertEqual(tokyo.time(date), "04:57")
        let twelve = SolarTimeFormatter(timeZone: TimeZone(identifier: "Europe/Paris")!, hourCycle: .twelveHour,
                                        locale: Locale(identifier: "en_US"))
        XCTAssertTrue(twelve.time(date).hasPrefix("9:57"), twelve.time(date))
    }

    func testDayOffset() {
        let zone = TimeZone(identifier: "Europe/Oslo")!
        let f = SolarTimeFormatter(timeZone: zone, hourCycle: .twentyFourHour, locale: Locale(identifier: "fr_FR"))
        let reference = Date(timeIntervalSince1970: 1_782_000_000) // 2026-06-21 ~02:00 Oslo
        XCTAssertEqual(f.time(reference.addingTimeInterval(-6 * 3600), relativeTo: reference).dayOffset, -1)
        XCTAssertEqual(f.time(reference, relativeTo: reference).dayOffset, 0)
    }
}
