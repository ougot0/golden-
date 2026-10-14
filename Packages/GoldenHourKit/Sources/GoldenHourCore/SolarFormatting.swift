import Foundation

/// Clock format chosen in Settings.
public enum HourCycle: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Follow the device's region settings.
    case system
    case twentyFourHour
    case twelveHour

    public var id: String { rawValue }
}

/// Formats times in the time zone of the place being viewed — not the device's time zone.
///
/// Planning a sunset in Tokyo from Paris must show Tokyo local time; the formatter carries the
/// place's time zone so this cannot be forgotten at a call site.
public struct SolarTimeFormatter {
    public let timeZone: TimeZone
    public let hourCycle: HourCycle
    public let locale: Locale
    private let formatter: DateFormatter

    public init(timeZone: TimeZone, hourCycle: HourCycle, locale: Locale = .current) {
        self.timeZone = timeZone
        self.hourCycle = hourCycle
        self.locale = locale
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        switch hourCycle {
        case .system: formatter.setLocalizedDateFormatFromTemplate("jmm")
        case .twentyFourHour: formatter.setLocalizedDateFormatFromTemplate("HHmm")
        case .twelveHour: formatter.setLocalizedDateFormatFromTemplate("hmma")
        }
        self.formatter = formatter
    }

    public func time(_ date: Date) -> String {
        formatter.string(from: date)
    }

    /// Time, followed by a day marker when `date` is not on `referenceDay` (e.g. a golden hour that
    /// started the previous evening at high latitude).
    public func time(_ date: Date, relativeTo referenceDayStart: Date) -> (time: String, dayOffset: Int) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let offset = calendar.dateComponents(
            [.day],
            from: calendar.startOfDay(for: referenceDayStart),
            to: calendar.startOfDay(for: date)
        ).day ?? 0
        return (time(date), offset)
    }
}

public enum DurationFormatting {
    /// "15 h 04", "42 min", "24 h 00". Seconds are rounded to the nearest minute.
    public static func hoursMinutes(_ interval: TimeInterval) -> String {
        let totalMinutes = Int((max(0, interval) / 60).rounded())
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60
        if hours == 0 { return "\(minutes) min" }
        return String(format: "%d h %02d", hours, minutes)
    }

    /// Countdown "2:05:09" / "4:09" (minutes:seconds under one hour). Rounds seconds up so it never
    /// shows 0:00 while the event is still in the future.
    public static func countdown(_ interval: TimeInterval) -> String {
        let total = max(0, Int(interval.rounded(.up)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 { return String(format: "%d:%02d:%02d", hours, minutes, seconds) }
        return String(format: "%d:%02d", minutes, seconds)
    }
}

public enum AngleFormatting {
    /// "123,4°" in French, "123.4°" in English.
    public static func degrees(_ value: Double, fractionDigits: Int = 1, locale: Locale = .current) -> String {
        let formatter = NumberFormatter()
        formatter.locale = locale
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = fractionDigits
        formatter.maximumFractionDigits = fractionDigits
        return (formatter.string(from: NSNumber(value: value)) ?? String(value)) + "°"
    }
}
