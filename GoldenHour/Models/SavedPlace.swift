import Foundation
import SwiftData
import SolarEngine
import GoldenHourCore

/// A favourite place, stored locally with SwiftData. Contains everything needed to compute solar
/// times offline (coordinates and IANA time zone).
@Model
final class SavedPlace {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Secondary line (locality, country) as returned by the search, or the formatted coordinates.
    var subtitle: String
    var latitude: Double
    var longitude: Double
    var timeZoneIdentifier: String
    /// `true` when the time zone could not be determined from the place and the device time zone was
    /// used instead. The UI asks the user to confirm it.
    var timeZoneIsEstimated: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        subtitle: String,
        coordinate: GeoCoordinate,
        timeZone: TimeZone,
        timeZoneIsEstimated: Bool,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.latitude = coordinate.latitude
        self.longitude = coordinate.longitude
        self.timeZoneIdentifier = timeZone.identifier
        self.timeZoneIsEstimated = timeZoneIsEstimated
        self.createdAt = createdAt
    }

    var coordinate: GeoCoordinate? {
        GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    var timeZone: TimeZone {
        TimeZone(identifier: timeZoneIdentifier) ?? .current
    }

    var activePlace: ActivePlace? {
        guard let coordinate else { return nil }
        return ActivePlace(
            name: name, subtitle: subtitle, coordinate: coordinate, timeZone: timeZone,
            timeZoneIsEstimated: timeZoneIsEstimated, source: .saved(id)
        )
    }
}
