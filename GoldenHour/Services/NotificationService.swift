import Foundation
import Observation
import SolarEngine
import GoldenHourCore
import UserNotifications

/// Schedules local notifications from a `NotificationPlanner` plan.
///
/// Every request uses a `UNTimeIntervalNotificationTrigger`, i.e. an absolute instant: an alert for a
/// sunset in Lisbon fires at the right moment even if the phone is in Paris. The plan is recomputed each
/// time the app becomes active, so the scheduling window slides forward and stays under the iOS limit of
/// 64 pending requests.
@MainActor
@Observable
final class NotificationService {
    private(set) var authorizationStatus: UNAuthorizationStatus = .notDetermined
    private(set) var scheduledCount = 0
    private(set) var lastPlanDroppedItems = false

    @ObservationIgnored private let center: UNUserNotificationCenter
    private static let managedPrefixes = ["solar.", "session."]

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    func refreshAuthorization() async {
        authorizationStatus = await center.notificationSettings().authorizationStatus
    }

    /// Asks for permission. Returns `true` if notifications may be delivered.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        await refreshAuthorization()
        return granted
    }

    var canDeliver: Bool {
        authorizationStatus == .authorized || authorizationStatus == .provisional || authorizationStatus == .ephemeral
    }

    /// Replaces every notification managed by the app with `plan`.
    func apply(_ plan: [PlannedNotification], hourCycle: HourCycle, now: Date = .now) async {
        await refreshAuthorization()
        let pending = await center.pendingNotificationRequests()
        let managed = pending.map(\.identifier).filter { id in Self.managedPrefixes.contains { id.hasPrefix($0) } }
        center.removePendingNotificationRequests(withIdentifiers: managed)

        guard canDeliver else {
            scheduledCount = 0
            return
        }
        // Requests created by other means (none today) still count toward the system limit.
        let budget = max(0, NotificationPlanner.systemPendingLimit - (pending.count - managed.count))
        var added = 0
        for item in plan.prefix(budget) {
            let interval = item.fireDate.timeIntervalSince(now)
            guard interval >= 1 else { continue }
            let request = UNNotificationRequest(
                identifier: item.identifier,
                content: NotificationText.content(for: item, hourCycle: hourCycle),
                trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            )
            do {
                try await center.add(request)
                added += 1
            } catch {
                // A failed request is skipped; the next re-plan retries it.
                continue
            }
        }
        scheduledCount = added
        lastPlanDroppedItems = plan.count > budget
    }
}

/// French notification texts.
enum NotificationText {
    static func content(for item: PlannedNotification, hourCycle: HourCycle) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        let time = SolarTimeFormatter(timeZone: item.timeZone, hourCycle: hourCycle).time(item.eventDate)
        content.sound = .default
        switch item.content {
        case let .solar(kind, placeName):
            let name = eventName(kind)
            content.title = item.offset == .atEvent ? name : "\(name) dans \(item.offset.minutes) min"
            content.body = "\(placeName) · \(time)"
            content.threadIdentifier = "solar"
        case let .session(_, title, placeName, anchor):
            content.title = title
            var parts: [String] = []
            switch anchor {
            case .startTime:
                parts.append(item.offset == .atEvent ? "Début de la séance" : "Début dans \(item.offset.minutes) min")
            case .solarEvent(let kind):
                parts.append(item.offset == .atEvent ? eventName(kind) : "\(eventName(kind)) dans \(item.offset.minutes) min")
            }
            parts.append(time)
            if let placeName { parts.append(placeName) }
            content.body = parts.joined(separator: " · ")
            content.threadIdentifier = "sessions"
        }
        return content
    }

    static func eventName(_ kind: SolarEventKind) -> String {
        switch kind {
        case .astronomicalDawn: return "Aube astronomique"
        case .nauticalDawn: return "Aube nautique"
        case .civilDawn: return "Aube civile"
        case .morningBlueHourStart: return "Heure bleue"
        case .morningGoldenHourStart: return "Heure dorée"
        case .sunrise: return "Lever du soleil"
        case .morningGoldenHourEnd: return "Fin de l'heure dorée"
        case .solarNoon: return "Midi solaire"
        case .eveningGoldenHourStart: return "Heure dorée"
        case .sunset: return "Coucher du soleil"
        case .eveningGoldenHourEnd: return "Heure bleue"
        case .eveningBlueHourEnd: return "Fin de l'heure bleue"
        case .civilDusk: return "Crépuscule civil"
        case .nauticalDusk: return "Crépuscule nautique"
        case .astronomicalDusk: return "Crépuscule astronomique"
        }
    }
}
