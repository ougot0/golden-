import Foundation

/// A validated geographic coordinate in decimal degrees (WGS 84).
///
/// Latitude is positive north, longitude positive east.
public struct GeoCoordinate: Hashable, Sendable, Codable {
    public let latitude: Double
    public let longitude: Double

    /// Returns `nil` when a value is not finite or outside [-90, 90] / [-180, 180].
    public init?(latitude: Double, longitude: Double) {
        guard latitude.isFinite, longitude.isFinite,
              (-90...90).contains(latitude), (-180...180).contains(longitude)
        else { return nil }
        self.latitude = latitude
        self.longitude = longitude
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let lat = try container.decode(Double.self, forKey: .latitude)
        let lon = try container.decode(Double.self, forKey: .longitude)
        guard let value = GeoCoordinate(latitude: lat, longitude: lon) else {
            throw DecodingError.dataCorruptedError(
                forKey: .latitude, in: container,
                debugDescription: "Coordinate out of range: \(lat), \(lon)"
            )
        }
        self = value
    }

    private enum CodingKeys: String, CodingKey { case latitude, longitude }
}
