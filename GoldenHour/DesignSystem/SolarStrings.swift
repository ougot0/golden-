import Foundation
import SolarEngine
import GoldenHourCore

/// French names for engine values.
enum SolarStrings {
    static func phase(_ phase: LightPhase) -> String {
        switch phase {
        case .night: return "Nuit"
        case .astronomicalTwilight: return "Crépuscule astronomique"
        case .nauticalTwilight: return "Crépuscule nautique"
        case .blueHour: return "Heure bleue"
        case .goldenHour: return "Heure dorée"
        case .daylight: return "Plein jour"
        }
    }

    static func period(_ period: LightPeriod) -> String {
        let name = phase(period.phase)
        switch period.part {
        case .morning: return "\(name) du matin"
        case .evening: return "\(name) du soir"
        case .continuous: return "\(name) continue"
        }
    }

    static func alert(_ kind: SolarAlertKind) -> String {
        switch kind {
        case .goldenHourStart: return "Début de l'heure dorée"
        case .blueHourStart: return "Début de l'heure bleue"
        case .sunrise: return "Lever du soleil"
        case .sunset: return "Coucher du soleil"
        }
    }

    static func reminder(_ offset: ReminderOffset) -> String {
        offset == .atEvent ? "À l'heure de l'événement" : "\(offset.minutes) min avant"
    }

    static func condition(_ condition: SunCondition) -> String? {
        switch condition {
        case .normal: return nil
        case .alwaysAbove: return "Soleil de minuit : le soleil reste au-dessus de l'horizon toute la journée."
        case .alwaysBelow: return "Nuit polaire : le soleil reste sous l'horizon toute la journée."
        }
    }
}

extension String {
    /// "jeudi 15 octobre" → "Jeudi 15 octobre". Unlike `capitalized`, keeps month names in lowercase
    /// as French typography requires.
    var capitalizingFirstLetter: String {
        prefix(1).uppercased() + dropFirst()
    }
}

/// Formats times for a solar day, adding "(veille)" / "(lendemain)" when a bound falls on another day.
struct DayTimeFormatter {
    let formatter: SolarTimeFormatter
    let dayStart: Date

    init(day: SolarDay, hourCycle: HourCycle) {
        formatter = SolarTimeFormatter(timeZone: day.timeZone, hourCycle: hourCycle)
        dayStart = day.interval.start
    }

    func time(_ date: Date?) -> String {
        guard let date else { return "—" }
        let (text, offset) = formatter.time(date, relativeTo: dayStart)
        switch offset {
        case 0: return text
        case ..<0: return "\(text) (veille)"
        default: return "\(text) (lendemain)"
        }
    }

    func range(_ period: LightPeriod?) -> String {
        guard let period else { return "—" }
        let start = (period.startIsOpen ? "avant " : "") + time(period.start)
        let end = (period.endIsOpen ? "après " : "") + time(period.end)
        return "\(start) – \(end)"
    }
}
