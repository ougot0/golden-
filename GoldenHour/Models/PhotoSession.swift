import Foundation
import SwiftData
import SolarEngine
import GoldenHourCore

/// A planned photo session.
///
/// The place is copied into the session (name, coordinates, time zone) rather than referenced, so a
/// session keeps working offline and stays valid if the favourite it came from is renamed or deleted.
@Model
final class PhotoSession {
    @Attribute(.unique) var id: UUID
    var title: String
    /// Start instant. For sessions anchored on a solar event this is the event time on the session day.
    var start: Date
    var notes: String
    var placeName: String?
    var latitude: Double?
    var longitude: Double?
    var timeZoneIdentifier: String?
    /// `SessionLightAnchor.rawValue`.
    var anchorRaw: String
    /// Minutes before the anchor; `nil` means no reminder.
    var reminderMinutes: Int?
    var createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        start: Date,
        notes: String = "",
        place: ActivePlace?,
        anchor: SessionLightAnchor,
        reminder: ReminderOffset?,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.start = start
        self.notes = notes
        self.anchorRaw = anchor.rawValue
        self.reminderMinutes = reminder?.rawValue
        self.createdAt = createdAt
        self.placeName = place?.name
        self.latitude = place?.coordinate.latitude
        self.longitude = place?.coordinate.longitude
        self.timeZoneIdentifier = place?.timeZone.identifier
    }

    func setPlace(_ place: ActivePlace?) {
        placeName = place?.name
        latitude = place?.coordinate.latitude
        longitude = place?.coordinate.longitude
        timeZoneIdentifier = place?.timeZone.identifier
    }

    var anchor: SessionLightAnchor {
        get { SessionLightAnchor(rawValue: anchorRaw) ?? .customTime }
        set { anchorRaw = newValue.rawValue }
    }

    var reminder: ReminderOffset? {
        get { reminderMinutes.flatMap(ReminderOffset.init(rawValue:)) }
        set { reminderMinutes = newValue?.rawValue }
    }

    var coordinate: GeoCoordinate? {
        guard let latitude, let longitude else { return nil }
        return GeoCoordinate(latitude: latitude, longitude: longitude)
    }

    /// Time zone of the session's place, or the device time zone for sessions without a place.
    var timeZone: TimeZone {
        timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
    }

    var place: ActivePlace? {
        guard let coordinate, let placeName else { return nil }
        return ActivePlace(
            name: placeName, subtitle: "", coordinate: coordinate, timeZone: timeZone,
            timeZoneIsEstimated: false, source: .manual
        )
    }

    var alertPlace: AlertPlace? {
        guard let coordinate, let placeName else { return nil }
        return AlertPlace(name: placeName, coordinate: coordinate, timeZone: timeZone)
    }

    var plannerInput: SessionInput? {
        guard let reminder else { return nil }
        return SessionInput(
            id: id.uuidString, title: title, start: start, place: alertPlace,
            anchor: anchor.sessionAnchor, offset: reminder
        )
    }
}

/// The light a session is planned around.
enum SessionLightAnchor: String, CaseIterable, Identifiable, Codable {
    case morningBlueHour
    case morningGoldenHour
    case sunrise
    case sunset
    case eveningGoldenHour
    case eveningBlueHour
    case customTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .morningBlueHour: return "Heure bleue du matin"
        case .morningGoldenHour: return "Heure dorée du matin"
        case .sunrise: return "Lever du soleil"
        case .sunset: return "Coucher du soleil"
        case .eveningGoldenHour: return "Heure dorée du soir"
        case .eveningBlueHour: return "Heure bleue du soir"
        case .customTime: return "Heure personnalisée"
        }
    }

    /// Solar event marking the start of the anchor, if any.
    var eventKind: SolarEventKind? {
        switch self {
        case .morningBlueHour: return .morningBlueHourStart
        case .morningGoldenHour: return .morningGoldenHourStart
        case .sunrise: return .sunrise
        case .sunset: return .sunset
        case .eveningGoldenHour: return .eveningGoldenHourStart
        case .eveningBlueHour: return .eveningGoldenHourEnd
        case .customTime: return nil
        }
    }

    var sessionAnchor: SessionAnchor {
        eventKind.map(SessionAnchor.solarEvent) ?? .startTime
    }
}
