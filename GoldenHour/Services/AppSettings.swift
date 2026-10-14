import Foundation
import Observation
import SwiftUI
import GoldenHourCore

enum AppTheme: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .system: return "Système"
        case .light: return "Clair"
        case .dark: return "Sombre"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

/// User preferences, persisted in `UserDefaults`.
@Observable
final class AppSettings {
    private enum Key {
        static let hourCycle = "settings.hourCycle"
        static let theme = "settings.theme"
        static let notificationsEnabled = "settings.notifications.enabled"
        static let solarAlerts = "settings.notifications.solarAlerts"
        static let solarOffset = "settings.notifications.offset"
        static let activePlace = "state.activePlace"
    }

    @ObservationIgnored private let defaults: UserDefaults

    var hourCycle: HourCycle {
        didSet { defaults.set(hourCycle.rawValue, forKey: Key.hourCycle) }
    }

    var theme: AppTheme {
        didSet { defaults.set(theme.rawValue, forKey: Key.theme) }
    }

    /// Master switch for solar alerts (session reminders are controlled per session).
    var solarNotificationsEnabled: Bool {
        didSet { defaults.set(solarNotificationsEnabled, forKey: Key.notificationsEnabled) }
    }

    var solarAlerts: Set<SolarAlertKind> {
        didSet { defaults.set(solarAlerts.map(\.rawValue).sorted(), forKey: Key.solarAlerts) }
    }

    var solarAlertOffset: ReminderOffset {
        didSet { defaults.set(solarAlertOffset.rawValue, forKey: Key.solarOffset) }
    }

    /// Last place used, restored at launch so the app works offline without asking for the location again.
    var activePlace: ActivePlace? {
        didSet {
            if let activePlace, let data = try? JSONEncoder().encode(activePlace) {
                defaults.set(data, forKey: Key.activePlace)
            } else {
                defaults.removeObject(forKey: Key.activePlace)
            }
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hourCycle = defaults.string(forKey: Key.hourCycle).flatMap(HourCycle.init(rawValue:)) ?? .system
        theme = defaults.string(forKey: Key.theme).flatMap(AppTheme.init(rawValue:)) ?? .system
        solarNotificationsEnabled = defaults.bool(forKey: Key.notificationsEnabled)
        if let raw = defaults.stringArray(forKey: Key.solarAlerts) {
            solarAlerts = Set(raw.compactMap(SolarAlertKind.init(rawValue:)))
        } else {
            solarAlerts = [.goldenHourStart]
        }
        solarAlertOffset = (defaults.object(forKey: Key.solarOffset) as? Int).flatMap(ReminderOffset.init(rawValue:)) ?? .fifteen
        activePlace = defaults.data(forKey: Key.activePlace).flatMap { try? JSONDecoder().decode(ActivePlace.self, from: $0) }
    }
}
