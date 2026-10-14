import Foundation
import XCTest
@testable import SolarEngine

/// Compares the engine against reference values computed with Skyfield + JPL DE421
/// (see `tools/reference/generate_solar_references.py`). 13 places from 78°N to 55°S,
/// 11 dates including equinoxes, solstices, DST transitions, a past and a future date.
final class ReferenceComparisonTests: XCTestCase {
    struct Fixture: Decodable {
        struct Crossing: Decodable { let date: String; let rising: Bool }
        struct Position: Decodable { let date: String; let elevation: Double; let azimuth: Double }
        struct Case: Decodable {
            let place: String
            let latitude: Double
            let longitude: Double
            let timeZone: String
            let date: String
            let crossings: [String: [Crossing]]
            let solarNoons: [String]
            let positions: [Position]
        }
        let thresholds: [Double]
        let cases: [Case]
    }

    static let fixture: Fixture = {
        let url = Bundle.module.url(forResource: "skyfield_reference", withExtension: "json", subdirectory: "Fixtures")!
        return try! JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }()

    static func parseDate(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string)!
    }

    static func localDate(_ string: String) -> LocalDate {
        let parts = string.split(separator: "-").map { Int($0)! }
        return LocalDate(year: parts[0], month: parts[1], day: parts[2])!
    }

    func testFixtureIsLoaded() {
        XCTAssertEqual(Self.fixture.cases.count, 13 * 11)
    }

    /// Time tolerance for a threshold crossing. Near the horizon the Sun's elevation changes at
    /// 15°/h × cos(latitude) × cos(declination) × sin(angle of the path); at high latitudes the path is
    /// shallow, so a fixed angular error translates into more seconds.
    private func tolerance(latitude: Double) -> TimeInterval {
        switch abs(latitude) {
        case ..<50: return 10
        case ..<67: return 15
        default: return 60
        }
    }

    func testThresholdCrossingsMatchReference() throws {
        var maxErrorByBand: [String: TimeInterval] = [:]
        var compared = 0
        for c in Self.fixture.cases {
            let coordinate = try XCTUnwrap(GeoCoordinate(latitude: c.latitude, longitude: c.longitude))
            let timeZone = try XCTUnwrap(TimeZone(identifier: c.timeZone))
            let date = Self.localDate(c.date)
            for threshold in Self.fixture.thresholds {
                let key = threshold == -0.8333 ? "-0.8333" : String(threshold)
                let reference = try XCTUnwrap(c.crossings[key], "missing threshold \(key)")
                let computed = SolarDayCalculator.crossings(of: threshold, on: date, coordinate: coordinate, timeZone: timeZone)
                XCTAssertEqual(computed.count, reference.count,
                               "\(c.place) \(c.date) threshold \(threshold): crossing count")
                guard computed.count == reference.count else { continue }
                for (mine, ref) in zip(computed, reference) {
                    XCTAssertEqual(mine.isRising, ref.rising, "\(c.place) \(c.date) \(threshold)")
                    let error = abs(mine.date.timeIntervalSince(Self.parseDate(ref.date)))
                    XCTAssertLessThanOrEqual(error, tolerance(latitude: c.latitude),
                                             "\(c.place) \(c.date) threshold \(threshold) rising=\(ref.rising)")
                    let band = abs(c.latitude) < 50 ? "|lat|<50" : abs(c.latitude) < 67 ? "50≤|lat|<67" : "|lat|≥67"
                    maxErrorByBand[band] = max(maxErrorByBand[band] ?? 0, error)
                    compared += 1
                }
            }
        }
        print("Compared \(compared) threshold crossings. Max error (s) by latitude band: \(maxErrorByBand)")
        XCTAssertGreaterThan(compared, 1000)
    }

    func testSolarNoonMatchesReference() throws {
        var maxError: TimeInterval = 0
        for c in Self.fixture.cases {
            let coordinate = try XCTUnwrap(GeoCoordinate(latitude: c.latitude, longitude: c.longitude))
            let timeZone = try XCTUnwrap(TimeZone(identifier: c.timeZone))
            let day = SolarDayCalculator.solarDay(for: Self.localDate(c.date), coordinate: coordinate, timeZone: timeZone)
            let computed = day.events.filter { $0.kind == .solarNoon }
            XCTAssertEqual(computed.count, c.solarNoons.count, "\(c.place) \(c.date)")
            for (mine, ref) in zip(computed, c.solarNoons) {
                let error = abs(mine.date.timeIntervalSince(Self.parseDate(ref)))
                maxError = max(maxError, error)
                XCTAssertLessThanOrEqual(error, 10, "\(c.place) \(c.date)")
            }
        }
        print("Solar noon max error: \(maxError) s")
    }

    func testPositionsMatchReference() throws {
        var maxElevationError = 0.0
        var maxAzimuthError = 0.0
        for c in Self.fixture.cases {
            let coordinate = try XCTUnwrap(GeoCoordinate(latitude: c.latitude, longitude: c.longitude))
            for sample in c.positions {
                let p = SolarCalculator.position(at: Self.parseDate(sample.date), coordinate: coordinate)
                let elevationError = abs(p.elevation - sample.elevation)
                XCTAssertLessThanOrEqual(elevationError, 0.02, "\(c.place) \(sample.date) elevation")
                maxElevationError = max(maxElevationError, elevationError)
                // An azimuth difference corresponds to an angle on the sky of Δaz × cos(elevation):
                // near the zenith a tiny position error produces a large azimuth difference.
                let azimuthError = abs(AstroMath.signedDegrees(p.azimuth - sample.azimuth))
                    * AstroMath.cosDeg(sample.elevation)
                XCTAssertLessThanOrEqual(azimuthError, 0.02, "\(c.place) \(sample.date) azimuth")
                maxAzimuthError = max(maxAzimuthError, azimuthError)
            }
        }
        print("Position max errors: elevation \(maxElevationError)°, azimuth×cos(h) \(maxAzimuthError)°")
    }
}
