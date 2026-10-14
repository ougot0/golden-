import Foundation
import SolarEngine

/// How long before an event a reminder fires.
public enum ReminderOffset: Int, CaseIterable, Codable, Sendable, Identifiable {
    case atEvent = 0
    case five = 5
    case ten = 10
    case fifteen = 15
    case thirty = 30
    case sixty = 60

    public var id: Int { rawValue }
    public var minutes: Int { rawValue }
    public var interval: TimeInterval { TimeInterval(rawValue * 60) }
}

/// Solar events a user can be notified about.
public enum SolarAlertKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case goldenHourStart
    case blueHourStart
    case sunrise
    case sunset

    public var id: String { rawValue }

    /// Engine events that trigger this alert.
    public var eventKinds: Set<SolarEventKind> {
        switch self {
        case .goldenHourStart: return [.morningGoldenHourStart, .eveningGoldenHourStart]
        case .blueHourStart: return [.morningBlueHourStart, .eveningGoldenHourEnd]
        case .sunrise: return [.sunrise]
        case .sunset: return [.sunset]
        }
    }
}

/// What a photo session's reminder is anchored to.
public enum SessionAnchor: Codable, Hashable, Sendable {
    /// A solar event on the session's local day at the session's place.
    case solarEvent(SolarEventKind)
    /// The session's own start time.
    case startTime
}

/// A place for which solar alerts are planned.
public struct AlertPlace: Hashable, Sendable {
    public let name: String
    public let coordinate: GeoCoordinate
    public let timeZone: TimeZone

    public init(name: String, coordinate: GeoCoordinate, timeZone: TimeZone) {
        self.name = name
        self.coordinate = coordinate
        self.timeZone = timeZone
    }
}

/// A planned photo session as seen by the planner (decoupled from SwiftData).
public struct SessionInput: Hashable, Sendable {
    public let id: String
    public let title: String
    public let start: Date
    public let place: AlertPlace?
    public let anchor: SessionAnchor
    public let offset: ReminderOffset

    public init(id: String, title: String, start: Date, place: AlertPlace?, anchor: SessionAnchor, offset: ReminderOffset) {
        self.id = id
        self.title = title
        self.start = start
        self.place = place
        self.anchor = anchor
        self.offset = offset
    }
}

/// A notification to schedule. Text is produced by the app layer so it can be localised.
public struct PlannedNotification: Hashable, Sendable {
    public enum Content: Hashable, Sendable {
        case solar(kind: SolarEventKind, placeName: String)
        case session(sessionID: String, title: String, placeName: String?, anchor: SessionAnchor)
    }

    /// Stable identifier: re-planning yields the same id for the same occurrence, so a reschedule
    /// replaces requests instead of duplicating them.
    public let identifier: String
    public let fireDate: Date
    /// The instant of the event itself (fireDate + offset).
    public let eventDate: Date
    public let offset: ReminderOffset
    public let timeZone: TimeZone
    public let content: Content

    public init(identifier: String, fireDate: Date, eventDate: Date, offset: ReminderOffset, timeZone: TimeZone, content: Content) {
        self.identifier = identifier
        self.fireDate = fireDate
        self.eventDate = eventDate
        self.offset = offset
        self.timeZone = timeZone
        self.content = content
    }
}

/// Plans local notifications while respecting iOS limits.
///
/// iOS keeps at most 64 pending local notifications per app and silently discards the others.
/// The planner therefore produces a bounded, prioritised list: session reminders first (they were
/// created explicitly by the user), then solar alerts in chronological order. The app re-plans
/// whenever it becomes active, when settings change and when sessions change, so the window slides
/// forward over time.
public struct NotificationPlanner: Sendable {
    public static let systemPendingLimit = 64

    public var limit: Int
    public var solarHorizonDays: Int
    public var conventions: LightConventions

    public init(limit: Int = NotificationPlanner.systemPendingLimit, solarHorizonDays: Int = 7, conventions: LightConventions = .standard) {
        self.limit = min(limit, Self.systemPendingLimit)
        self.solarHorizonDays = solarHorizonDays
        self.conventions = conventions
    }

    public func plan(
        now: Date,
        solarAlerts: Set<SolarAlertKind>,
        solarOffset: ReminderOffset,
        place: AlertPlace?,
        sessions: [SessionInput]
    ) -> [PlannedNotification] {
        var sessionNotifications: [PlannedNotification] = sessions.compactMap { session in
            guard let eventDate = resolve(session) else { return nil }
            let fire = eventDate.addingTimeInterval(-session.offset.interval)
            guard fire > now else { return nil }
            return PlannedNotification(
                identifier: "session.\(session.id)",
                fireDate: fire,
                eventDate: eventDate,
                offset: session.offset,
                timeZone: session.place?.timeZone ?? .current,
                content: .session(sessionID: session.id, title: session.title, placeName: session.place?.name, anchor: session.anchor)
            )
        }
        sessionNotifications.sort { $0.fireDate < $1.fireDate }

        var solarNotifications: [PlannedNotification] = []
        if let place, !solarAlerts.isEmpty {
            let kinds = solarAlerts.reduce(into: Set<SolarEventKind>()) { $0.formUnion($1.eventKinds) }
            let events = LightForecast.upcomingEvents(
                after: now, kinds: kinds, coordinate: place.coordinate, timeZone: place.timeZone,
                days: solarHorizonDays, conventions: conventions
            )
            for event in events {
                let fire = event.date.addingTimeInterval(-solarOffset.interval)
                guard fire > now else { continue }
                solarNotifications.append(PlannedNotification(
                    identifier: "solar.\(event.kind.rawValue).\(Int(event.date.timeIntervalSince1970 / 60))",
                    fireDate: fire,
                    eventDate: event.date,
                    offset: solarOffset,
                    timeZone: place.timeZone,
                    content: .solar(kind: event.kind, placeName: place.name)
                ))
            }
        }

        let sessionsKept = Array(sessionNotifications.prefix(limit))
        let solarKept = Array(solarNotifications.prefix(max(0, limit - sessionsKept.count)))
        return (sessionsKept + solarKept).sorted { $0.fireDate < $1.fireDate }
    }

    /// The instant a session reminder refers to, or `nil` if the anchored solar event does not occur
    /// that day (e.g. no golden hour during the polar night).
    public func resolve(_ session: SessionInput) -> Date? {
        switch session.anchor {
        case .startTime:
            return session.start
        case .solarEvent(let kind):
            guard let place = session.place else { return nil }
            let day = SolarDayCalculator.solarDay(
                for: LocalDate(session.start, in: place.timeZone),
                coordinate: place.coordinate, timeZone: place.timeZone, conventions: conventions
            )
            return day.event(kind)?.date
        }
    }
}
