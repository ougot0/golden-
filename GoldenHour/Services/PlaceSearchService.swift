import CoreLocation
import Foundation
import MapKit
import Observation
import SolarEngine

/// Place search with Apple's free MapKit services (`MKLocalSearchCompleter` + `MKLocalSearch`).
///
/// Requires a network connection; favourites are stored with their coordinates and time zone so they
/// keep working offline afterwards.
@MainActor
@Observable
final class PlaceSearchService: NSObject, MKLocalSearchCompleterDelegate {
    struct Suggestion: Identifiable, Hashable {
        let id: String
        let title: String
        let subtitle: String
        fileprivate let completion: MKLocalSearchCompletion
    }

    var query = "" {
        didSet { updateQuery() }
    }
    private(set) var suggestions: [Suggestion] = []
    private(set) var isSearching = false
    private(set) var errorMessage: String?

    @ObservationIgnored private let completer: MKLocalSearchCompleter

    override init() {
        let completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address, .pointOfInterest]
        self.completer = completer
        super.init()
        completer.delegate = self
    }

    private func updateQuery() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        errorMessage = nil
        if trimmed.isEmpty {
            completer.cancel()
            suggestions = []
            isSearching = false
        } else {
            isSearching = true
            completer.queryFragment = trimmed
        }
    }

    /// Resolves a suggestion into a place with coordinates and time zone.
    func resolve(_ suggestion: Suggestion) async throws -> ActivePlace {
        let request = MKLocalSearch.Request(completion: suggestion.completion)
        let response = try await MKLocalSearch(request: request).start()
        guard let item = response.mapItems.first,
              let coordinate = GeoCoordinate(
                latitude: item.placemark.coordinate.latitude,
                longitude: item.placemark.coordinate.longitude
              )
        else {
            throw LocationError.unavailable(underlying: nil)
        }
        var timeZone = item.timeZone
        if timeZone == nil {
            timeZone = try? await PlaceGeocoder.timeZone(for: coordinate)
        }
        return ActivePlace(
            name: item.name ?? suggestion.title,
            subtitle: suggestion.subtitle,
            coordinate: coordinate,
            timeZone: timeZone ?? .current,
            timeZoneIsEstimated: timeZone == nil,
            source: .manual
        )
    }

    // MARK: MKLocalSearchCompleterDelegate

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        let results = completer.results
        MainActor.assumeIsolated {
            suggestions = results.map {
                Suggestion(id: "\($0.title)|\($0.subtitle)", title: $0.title, subtitle: $0.subtitle, completion: $0)
            }
            isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        MainActor.assumeIsolated {
            isSearching = false
            suggestions = []
            errorMessage = "La recherche nécessite une connexion Internet. Les lieux enregistrés restent disponibles hors ligne."
        }
    }
}

/// Reverse geocoding (place name and time zone from coordinates) with `CLGeocoder`.
enum PlaceGeocoder {
    struct Result {
        let name: String?
        let subtitle: String?
        let timeZone: TimeZone?
    }

    static func reverse(_ coordinate: GeoCoordinate) async throws -> Result {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try await CLGeocoder().reverseGeocodeLocation(location)
        guard let placemark = placemarks.first else { return Result(name: nil, subtitle: nil, timeZone: nil) }
        let name = placemark.locality ?? placemark.name ?? placemark.administrativeArea
        let subtitle = [placemark.administrativeArea, placemark.country].compactMap { $0 }.joined(separator: ", ")
        return Result(name: name, subtitle: subtitle.isEmpty ? nil : subtitle, timeZone: placemark.timeZone)
    }

    static func timeZone(for coordinate: GeoCoordinate) async throws -> TimeZone? {
        try await reverse(coordinate).timeZone
    }
}
