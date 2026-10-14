import Foundation
import SolarEngine
import GoldenHourCore

/// The place currently used by the dashboard, calendar and compass.
struct ActivePlace: Equatable, Codable {
    enum Source: Equatable, Codable {
        /// GPS position, refreshed on request.
        case currentLocation
        /// A favourite stored in SwiftData.
        case saved(UUID)
        /// Search result or coordinates typed by the user, not saved as a favourite.
        case manual
    }

    var name: String
    var subtitle: String
    var coordinate: GeoCoordinate
    var timeZoneIdentifier: String
    var timeZoneIsEstimated: Bool
    var source: Source

    init(name: String, subtitle: String, coordinate: GeoCoordinate, timeZone: TimeZone,
         timeZoneIsEstimated: Bool, source: Source) {
        self.name = name
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.timeZoneIdentifier = timeZone.identifier
        self.timeZoneIsEstimated = timeZoneIsEstimated
        self.source = source
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    var alertPlace: AlertPlace {
        AlertPlace(name: name, coordinate: coordinate, timeZone: timeZone)
    }

    /// "48,8566° N, 2,3522° E"
    var formattedCoordinate: String {
        ActivePlace.format(coordinate)
    }

    static func format(_ c: GeoCoordinate) -> String {
        let lat = AngleFormatting.degrees(abs(c.latitude), fractionDigits: 4)
        let lon = AngleFormatting.degrees(abs(c.longitude), fractionDigits: 4)
        return "\(lat) \(c.latitude >= 0 ? "N" : "S"), \(lon) \(c.longitude >= 0 ? "E" : "O")"
    }
}
