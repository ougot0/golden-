import Foundation

/// Current light situation and next photographic period, used for the dashboard countdown.
public struct LightStatus: Sendable {
    public let date: Date
    public let phase: LightPhase
    /// The golden or blue hour in progress, if any.
    public let currentPeriod: LightPeriod?
    /// The next golden or blue hour that starts strictly after `date`, if one exists within the search horizon.
    public let nextPeriod: LightPeriod?
    /// Number of days that were searched for `nextPeriod`.
    public let searchedDays: Int
}

public enum LightForecast {
    /// - Parameter maximumDays: search horizon for the next period. Inside the polar circles the Sun may
    ///   not reach the golden/blue bands for weeks; the caller should then report that none was found
    ///   within `maximumDays` rather than guessing.
    public static func status(
        at date: Date,
        coordinate: GeoCoordinate,
        timeZone: TimeZone,
        conventions: LightConventions = .standard,
        maximumDays: Int = 30
    ) -> LightStatus {
        let position = SolarCalculator.position(at: date, coordinate: coordinate)
        let phase = conventions.phase(forElevation: position.elevation)
        let today = LocalDate(date, in: timeZone)

        var current: LightPeriod?
        var next: LightPeriod?
        var searched = 0
        for offset in 0..<max(1, maximumDays) {
            searched = offset + 1
            let day = SolarDayCalculator.solarDay(
                for: today.adding(days: offset), coordinate: coordinate, timeZone: timeZone, conventions: conventions
            )
            let periods = (day.goldenHours + day.blueHours).sorted { $0.start < $1.start }
            if current == nil, offset == 0 {
                current = periods.first { $0.contains(date) }
            }
            if let candidate = periods.first(where: { $0.start > date && !$0.startIsOpen }) {
                next = candidate
                break
            }
        }
        return LightStatus(date: date, phase: phase, currentPeriod: current, nextPeriod: next, searchedDays: searched)
    }

    /// Upcoming events of the given kinds, in chronological order, starting strictly after `date`.
    /// Used to plan local notifications.
    public static func upcomingEvents(
        after date: Date,
        kinds: Set<SolarEventKind>,
        coordinate: GeoCoordinate,
        timeZone: TimeZone,
        days: Int,
        conventions: LightConventions = .standard
    ) -> [SolarEvent] {
        let start = LocalDate(date, in: timeZone)
        var result: [SolarEvent] = []
        for offset in 0..<max(0, days) {
            let day = SolarDayCalculator.solarDay(
                for: start.adding(days: offset), coordinate: coordinate, timeZone: timeZone, conventions: conventions
            )
            result += day.events.filter { kinds.contains($0.kind) && $0.date > date }
        }
        return result.sorted { $0.date < $1.date }
    }
}

/// Points along the Sun's path across the sky, for the compass and the sky chart.
public enum SolarPath {
    public struct Sample: Hashable, Sendable {
        public let date: Date
        public let azimuth: Double
        public let elevation: Double
    }

    /// Positions sampled every `step` seconds over the local day (both ends included).
    public static func samples(
        for date: LocalDate,
        coordinate: GeoCoordinate,
        timeZone: TimeZone,
        step: TimeInterval = 600
    ) -> [Sample] {
        precondition(step > 0)
        let day = date.interval(in: timeZone)
        var result: [Sample] = []
        var t = day.start
        while t <= day.end {
            let p = SolarCalculator.position(at: t, coordinate: coordinate)
            result.append(Sample(date: t, azimuth: p.azimuth, elevation: p.elevation))
            t = t.addingTimeInterval(step)
        }
        return result
    }
}
