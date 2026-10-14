import Foundation

/// A calendar date (year, month, day) without a time or a time zone.
///
/// Solar events are computed for a *local* calendar day at a place. Representing the day explicitly
/// avoids the classic bug of using a `Date` (an instant) whose calendar day differs between the device
/// time zone and the time zone of the place being planned.
public struct LocalDate: Hashable, Comparable, Sendable, Codable, Identifiable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Returns `nil` if the components do not form a valid Gregorian date.
    public init?(year: Int, month: Int, day: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let components = DateComponents(year: year, month: month, day: day, hour: 12)
        guard let date = calendar.date(from: components) else { return nil }
        let check = calendar.dateComponents([.year, .month, .day], from: date)
        guard check.year == year, check.month == month, check.day == day else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The calendar date of `date` as seen in `timeZone`.
    public init(_ date: Date, in timeZone: TimeZone) {
        let calendar = Calendar.gregorian(in: timeZone)
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = c.year!
        self.month = c.month!
        self.day = c.day!
    }

    /// Start of this day in `timeZone`. Handles time zones where midnight does not exist on DST days.
    public func startOfDay(in timeZone: TimeZone) -> Date {
        let calendar = Calendar.gregorian(in: timeZone)
        // Noon always exists, even on DST transition days.
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return calendar.startOfDay(for: noon)
    }

    /// The local day as an interval [start, start of next day). Its length is 23, 24 or 25 hours.
    public func interval(in timeZone: TimeZone) -> DateInterval {
        DateInterval(start: startOfDay(in: timeZone), end: adding(days: 1).startOfDay(in: timeZone))
    }

    public func adding(days: Int) -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let noon = calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
        return LocalDate(calendar.date(byAdding: .day, value: days, to: noon)!, in: calendar.timeZone)
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var id: String { description }

    public var description: String {
        String(format: "%04d-%02d-%02d", year, month, day)
    }
}

extension Calendar {
    static func gregorian(in timeZone: TimeZone) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar
    }
}
