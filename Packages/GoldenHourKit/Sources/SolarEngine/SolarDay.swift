import Foundation

/// A named solar event (threshold crossing or meridian transit).
public enum SolarEventKind: String, CaseIterable, Sendable, Codable {
    case astronomicalDawn
    case nauticalDawn
    case civilDawn
    case morningBlueHourStart
    case morningGoldenHourStart   // = end of the morning blue hour
    case sunrise
    case morningGoldenHourEnd
    case solarNoon
    case eveningGoldenHourStart
    case sunset
    case eveningGoldenHourEnd     // = start of the evening blue hour
    case eveningBlueHourEnd
    case civilDusk
    case nauticalDusk
    case astronomicalDusk
}

public struct SolarEvent: Hashable, Sendable, Codable {
    public let kind: SolarEventKind
    public let date: Date
    /// Geometric solar elevation at the event, in degrees.
    public let elevation: Double

    public init(kind: SolarEventKind, date: Date, elevation: Double) {
        self.kind = kind
        self.date = date
        self.elevation = elevation
    }
}

/// A crossing of an elevation threshold by the Sun's centre.
public struct ThresholdCrossing: Hashable, Sendable {
    public let date: Date
    /// `true` when the Sun is rising through the threshold.
    public let isRising: Bool
}

/// A contiguous interval during which the light phase is constant.
public struct LightSegment: Hashable, Sendable {
    public let phase: LightPhase
    public let interval: DateInterval
}

/// A golden or blue hour.
public struct LightPeriod: Hashable, Sendable {
    public enum Part: String, Sendable, Codable {
        /// Sun rising through the band.
        case morning
        /// Sun setting through the band.
        case evening
        /// The Sun enters and leaves the band from the same side (e.g. a winter day at high latitude
        /// where the Sun never climbs above the golden-hour band, or a summer night where it never sinks
        /// below it).
        case continuous
    }

    public let phase: LightPhase
    public let part: Part
    public let start: Date
    public let end: Date
    /// `true` if the period had already started more than `SolarDay.searchMargin` before `start`
    /// (`start` is then a lower bound, not the real beginning).
    public let startIsOpen: Bool
    /// `true` if the period continues more than `SolarDay.searchMargin` after `end`.
    public let endIsOpen: Bool

    public var interval: DateInterval { DateInterval(start: start, end: end) }
    public var duration: TimeInterval { end.timeIntervalSince(start) }

    public func contains(_ date: Date) -> Bool { date >= start && date < end }
}

/// Behaviour of the Sun relative to the horizon during a local day.
public enum SunCondition: String, Sendable, Codable {
    /// The Sun rises and/or sets during the day.
    case normal
    /// The Sun stays above the horizon all day (midnight sun / polar day).
    case alwaysAbove
    /// The Sun stays below the horizon all day (polar night).
    case alwaysBelow
}

/// All solar information for one local calendar day at one place.
public struct SolarDay: Sendable {
    /// Light periods are searched up to this far outside the day so that a golden hour that started
    /// before midnight is reported with its real start time.
    public static let searchMargin: TimeInterval = 12 * 3600

    public let date: LocalDate
    public let coordinate: GeoCoordinate
    public let timeZone: TimeZone
    public let conventions: LightConventions
    /// The local day [00:00, next 00:00) — 23, 24 or 25 hours long.
    public let interval: DateInterval
    /// Every event that happens during the local day, sorted chronologically.
    public let events: [SolarEvent]
    /// Light phases covering exactly `interval`, sorted.
    public let timeline: [LightSegment]
    /// Golden hours that overlap the local day (bounds may fall on the previous or next day).
    public let goldenHours: [LightPeriod]
    /// Blue hours that overlap the local day (bounds may fall on the previous or next day).
    public let blueHours: [LightPeriod]
    /// Time with the Sun above the horizon (−0.833°) during the local day.
    public let daylightDuration: TimeInterval
    public let sunCondition: SunCondition
    /// Highest geometric elevation reached during the day.
    public let maximumElevation: Double
    /// Lowest geometric elevation reached during the day.
    public let minimumElevation: Double

    // MARK: Convenience accessors

    public func event(_ kind: SolarEventKind) -> SolarEvent? {
        switch kind {
        // Rising events: report the first occurrence, setting events: the last one.
        // On days near the polar boundary a "sunset" from the previous evening can spill past midnight;
        // the evening event of *this* day is then the last one.
        case .eveningGoldenHourStart, .sunset, .eveningGoldenHourEnd, .eveningBlueHourEnd,
             .civilDusk, .nauticalDusk, .astronomicalDusk:
            return events.last { $0.kind == kind }
        default:
            return events.first { $0.kind == kind }
        }
    }

    public var sunrise: Date? { event(.sunrise)?.date }
    public var sunset: Date? { event(.sunset)?.date }
    public var solarNoon: Date? { event(.solarNoon)?.date }

    public var morningGoldenHour: LightPeriod? { goldenHours.first { $0.part == .morning } }
    public var eveningGoldenHour: LightPeriod? { goldenHours.last { $0.part == .evening } }
    public var morningBlueHour: LightPeriod? { blueHours.first { $0.part == .morning } }
    public var eveningBlueHour: LightPeriod? { blueHours.last { $0.part == .evening } }

    public func phase(at date: Date) -> LightPhase? {
        timeline.first { $0.interval.start <= date && date < $0.interval.end }?.phase
    }
}

/// Computes `SolarDay` values.
///
/// Method: the geometric elevation of the Sun is sampled every `sampleStep` seconds over the local day
/// (extended by `SolarDay.searchMargin` on each side). Every sign change of `elevation − threshold`
/// is refined by bisection to better than 0.5 s. Because the search is purely numerical it handles
/// daylight-saving transitions (the local day simply has 23 or 25 hours), polar days, polar nights,
/// and days with several crossings of the same threshold.
///
/// Limitation: two crossings of the same threshold less than `sampleStep` apart (the Sun grazing a
/// threshold for a couple of minutes, only possible very close to the polar circles) can be missed.
public enum SolarDayCalculator {
    public static let sampleStep: TimeInterval = 300
    private static let bisectionTolerance: TimeInterval = 0.25

    public static func solarDay(
        for date: LocalDate,
        coordinate: GeoCoordinate,
        timeZone: TimeZone,
        conventions: LightConventions = .standard
    ) -> SolarDay {
        let day = date.interval(in: timeZone)
        let windowStart = day.start.timeIntervalSince1970 - SolarDay.searchMargin
        let windowEnd = day.end.timeIntervalSince1970 + SolarDay.searchMargin
        let lat = coordinate.latitude
        let lon = coordinate.longitude

        func elevation(_ t: Double) -> Double {
            SolarCalculator.position(unixTime: t, latitude: lat, longitude: lon).elevation
        }

        // 1. Sample the elevation curve.
        var times: [Double] = []
        var t = windowStart
        while t < windowEnd {
            times.append(t)
            t += sampleStep
        }
        times.append(windowEnd)
        let elevations = times.map(elevation)

        // 2. Threshold crossings, refined by bisection.
        var crossingsByThreshold: [Double: [ThresholdCrossing]] = [:]
        for threshold in conventions.allThresholds {
            var result: [ThresholdCrossing] = []
            for i in 0..<(times.count - 1) {
                let a = elevations[i] - threshold
                let b = elevations[i + 1] - threshold
                guard (a < 0) != (b < 0) else { continue }
                let rising = b >= 0
                let root = bisect(lo: times[i], hi: times[i + 1], loIsBelow: rising) {
                    elevation($0) >= threshold
                }
                result.append(ThresholdCrossing(date: Date(timeIntervalSince1970: root), isRising: rising))
            }
            crossingsByThreshold[threshold] = result
        }

        // 3. Named events inside the local day.
        var events: [SolarEvent] = []
        func addEvents(threshold: Double, rising: SolarEventKind, setting: SolarEventKind) {
            for crossing in crossingsByThreshold[threshold] ?? [] where day.contains(crossing.date) && crossing.date < day.end {
                events.append(SolarEvent(kind: crossing.isRising ? rising : setting, date: crossing.date, elevation: threshold))
            }
        }
        addEvents(threshold: SolarThreshold.astronomicalTwilight, rising: .astronomicalDawn, setting: .astronomicalDusk)
        addEvents(threshold: SolarThreshold.nauticalTwilight, rising: .nauticalDawn, setting: .nauticalDusk)
        addEvents(threshold: SolarThreshold.civilTwilight, rising: .civilDawn, setting: .civilDusk)
        addEvents(threshold: conventions.blueHourLower, rising: .morningBlueHourStart, setting: .eveningBlueHourEnd)
        addEvents(threshold: conventions.goldenHourLower, rising: .morningGoldenHourStart, setting: .eveningGoldenHourEnd)
        addEvents(threshold: SolarThreshold.horizon, rising: .sunrise, setting: .sunset)
        addEvents(threshold: conventions.goldenHourUpper, rising: .morningGoldenHourEnd, setting: .eveningGoldenHourStart)

        // Solar noon: hour angle crossing zero from negative to positive.
        for i in 0..<(times.count - 1) where times[i] >= day.start.timeIntervalSince1970 - sampleStep {
            let h0 = SolarCalculator.position(unixTime: times[i], latitude: lat, longitude: lon).hourAngle
            let h1 = SolarCalculator.position(unixTime: times[i + 1], latitude: lat, longitude: lon).hourAngle
            guard h0 < 0, h1 >= 0, h1 - h0 < 90 else { continue }
            let root = bisect(lo: times[i], hi: times[i + 1], loIsBelow: true) {
                SolarCalculator.position(unixTime: $0, latitude: lat, longitude: lon).hourAngle >= 0
            }
            let noon = Date(timeIntervalSince1970: root)
            if day.contains(noon) && noon < day.end {
                events.append(SolarEvent(kind: .solarNoon, date: noon, elevation: elevation(root)))
            }
        }
        events.sort { $0.date < $1.date }

        // 4. Phase segments over the whole search window.
        var boundaries: [Double] = [windowStart, windowEnd]
        for threshold in conventions.phaseThresholds {
            boundaries += (crossingsByThreshold[threshold] ?? []).map { $0.date.timeIntervalSince1970 }
        }
        boundaries.sort()
        var windowSegments: [(phase: LightPhase, start: Double, end: Double)] = []
        for i in 0..<(boundaries.count - 1) where boundaries[i + 1] > boundaries[i] {
            let mid = (boundaries[i] + boundaries[i + 1]) / 2
            let phase = conventions.phase(forElevation: elevation(mid))
            if let last = windowSegments.last, last.phase == phase {
                windowSegments[windowSegments.count - 1].end = boundaries[i + 1]
            } else {
                windowSegments.append((phase, boundaries[i], boundaries[i + 1]))
            }
        }

        // 5. Timeline clipped to the local day.
        let dayStart = day.start.timeIntervalSince1970
        let dayEnd = day.end.timeIntervalSince1970
        let timeline: [LightSegment] = windowSegments.compactMap { segment in
            let start = max(segment.start, dayStart)
            let end = min(segment.end, dayEnd)
            guard end > start else { return nil }
            return LightSegment(
                phase: segment.phase,
                interval: DateInterval(start: Date(timeIntervalSince1970: start), end: Date(timeIntervalSince1970: end))
            )
        }

        // 6. Golden and blue periods overlapping the day, with unclipped bounds.
        func periods(of phase: LightPhase) -> [LightPeriod] {
            windowSegments.compactMap { segment in
                guard segment.phase == phase, segment.end > dayStart, segment.start < dayEnd else { return nil }
                let startOpen = segment.start <= windowStart
                let endOpen = segment.end >= windowEnd
                let risingAtStart = elevation(segment.start + 60) > elevation(segment.start)
                let risingAtEnd = elevation(segment.end) > elevation(segment.end - 60)
                let part: LightPeriod.Part
                switch (risingAtStart, risingAtEnd) {
                case (true, true): part = .morning
                case (false, false): part = .evening
                default: part = .continuous
                }
                return LightPeriod(
                    phase: phase, part: part,
                    start: Date(timeIntervalSince1970: segment.start),
                    end: Date(timeIntervalSince1970: segment.end),
                    startIsOpen: startOpen, endIsOpen: endOpen
                )
            }
        }

        // 7. Daylight duration and sun condition.
        let horizonCrossings = (crossingsByThreshold[SolarThreshold.horizon] ?? [])
            .map { $0.date.timeIntervalSince1970 }
            .filter { $0 > dayStart && $0 < dayEnd }
        var daylight: Double = 0
        var cursor = dayStart
        var isUp = elevation(dayStart) >= SolarThreshold.horizon
        for crossing in horizonCrossings {
            if isUp { daylight += crossing - cursor }
            cursor = crossing
            isUp.toggle()
        }
        if isUp { daylight += dayEnd - cursor }

        let dayIndices = times.indices.filter { times[$0] >= dayStart && times[$0] <= dayEnd }
        var maxElevation = dayIndices.map { elevations[$0] }.max() ?? elevation(dayStart)
        var minElevation = dayIndices.map { elevations[$0] }.min() ?? elevation(dayStart)
        if let noon = events.first(where: { $0.kind == .solarNoon }) {
            maxElevation = max(maxElevation, noon.elevation)
        }
        minElevation = min(minElevation, elevation(dayStart), elevation(dayEnd))

        let condition: SunCondition
        if !horizonCrossings.isEmpty {
            condition = .normal
        } else {
            condition = elevation(dayStart) >= SolarThreshold.horizon ? .alwaysAbove : .alwaysBelow
        }

        return SolarDay(
            date: date,
            coordinate: coordinate,
            timeZone: timeZone,
            conventions: conventions,
            interval: day,
            events: events,
            timeline: timeline,
            goldenHours: periods(of: .goldenHour),
            blueHours: periods(of: .blueHour),
            daylightDuration: daylight,
            sunCondition: condition,
            maximumElevation: maxElevation,
            minimumElevation: minElevation
        )
    }

    /// Every crossing of an arbitrary elevation threshold during a local day.
    public static func crossings(
        of threshold: Double,
        on date: LocalDate,
        coordinate: GeoCoordinate,
        timeZone: TimeZone
    ) -> [ThresholdCrossing] {
        let day = date.interval(in: timeZone)
        let lat = coordinate.latitude
        let lon = coordinate.longitude
        func f(_ t: Double) -> Double {
            SolarCalculator.position(unixTime: t, latitude: lat, longitude: lon).elevation - threshold
        }
        var result: [ThresholdCrossing] = []
        var t0 = day.start.timeIntervalSince1970
        let end = day.end.timeIntervalSince1970
        var v0 = f(t0)
        while t0 < end {
            let t1 = min(t0 + sampleStep, end)
            let v1 = f(t1)
            if (v0 < 0) != (v1 < 0) {
                let rising = v1 >= 0
                let root = bisect(lo: t0, hi: t1, loIsBelow: rising) { f($0) >= 0 }
                result.append(ThresholdCrossing(date: Date(timeIntervalSince1970: root), isRising: rising))
            }
            t0 = t1
            v0 = v1
        }
        return result
    }

    /// Bisection on a boolean predicate that changes value exactly once in [lo, hi].
    /// `loIsBelow` tells whether the predicate is `false` at `lo`.
    private static func bisect(lo: Double, hi: Double, loIsBelow: Bool, isAbove: (Double) -> Bool) -> Double {
        var lo = lo
        var hi = hi
        while hi - lo > bisectionTolerance {
            let mid = (lo + hi) / 2
            if isAbove(mid) == loIsBelow {
                hi = mid
            } else {
                lo = mid
            }
        }
        return (lo + hi) / 2
    }
}
