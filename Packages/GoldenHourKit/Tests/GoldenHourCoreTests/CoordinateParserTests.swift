import XCTest
@testable import GoldenHourCore

final class CoordinateParserTests: XCTestCase {
    private func assertParses(_ input: String, _ lat: Double, _ lon: Double, file: StaticString = #filePath, line: UInt = #line) {
        guard let c = CoordinateParser.parse(input) else {
            return XCTFail("Could not parse \(input)", file: file, line: line)
        }
        XCTAssertEqual(c.latitude, lat, accuracy: 1e-4, file: file, line: line)
        XCTAssertEqual(c.longitude, lon, accuracy: 1e-4, file: file, line: line)
    }

    func testDecimal() {
        assertParses("48.8566, 2.3522", 48.8566, 2.3522)
        assertParses("-33.8688,151.2093", -33.8688, 151.2093)
        assertParses("48,8566 2,3522", 48.8566, 2.3522)
        assertParses("48,8566; -2,3522", 48.8566, -2.3522)
        assertParses("  40.7128 -74.0060 ", 40.7128, -74.0060)
    }

    func testHemispheres() {
        assertParses("48.8566 N 2.3522 E", 48.8566, 2.3522)
        assertParses("33.8688 S 151.2093 E", -33.8688, 151.2093)
        assertParses("N40.7128 W74.0060", 40.7128, -74.0060)
        assertParses("40.7128 N, 74.0060 O", 40.7128, -74.0060)
    }

    func testDegreesMinutesSeconds() {
        assertParses("48°51'24\"N 2°21'08\"E", 48 + 51.0 / 60 + 24.0 / 3600, 2 + 21.0 / 60 + 8.0 / 3600)
        assertParses("48° 51.4' N, 2° 21.1' E", 48 + 51.4 / 60, 2 + 21.1 / 60)
        assertParses("33°52′08″S 151°12′33″E", -(33 + 52.0 / 60 + 8.0 / 3600), 151 + 12.0 / 60 + 33.0 / 3600)
    }

    func testRejectsInvalidInput() {
        XCTAssertNil(CoordinateParser.parse(""))
        XCTAssertNil(CoordinateParser.parse("Paris"))
        XCTAssertNil(CoordinateParser.parse("91, 0"))
        XCTAssertNil(CoordinateParser.parse("45, 200"))
        XCTAssertNil(CoordinateParser.parse("45°75' N 2 E"))
        XCTAssertNil(CoordinateParser.parse("-45 S, 2 E"))
        XCTAssertNil(CoordinateParser.parse("1, 2, 3"))
    }
}
