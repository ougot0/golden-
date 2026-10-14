import CoreLocation
import Foundation
import Observation
import SwiftData
import SolarEngine
import GoldenHourCore

/// Shared application state: the active place, the selected date, and the services.
@MainActor
@Observable
final class AppModel {
    let settings: AppSettings
    let location: LocationService
    let notifications: NotificationService
    let entitlements: any EntitlementProviding

    /// Date shown by the dashboard and the compass, in the active place's calendar.
    var selectedDate: LocalDate
    var selectedTab: AppTab = .today
    private(set) var locationError: String?

    init(
        settings: AppSettings,
        location: LocationService,
        notifications: NotificationService,
        entitlements: any EntitlementProviding = PaidUpfrontEntitlements()
    ) {
        self.settings = settings
        self.location = location
        self.notifications = notifications
        self.entitlements = entitlements
        let zone = settings.activePlace?.timeZone ?? .current
        selectedDate = LocalDate(.now, in: zone)
    }

    var place: ActivePlace? { settings.activePlace }

    /// Today in the active place's time zone (not necessarily the device's).
    var today: LocalDate {
        LocalDate(.now, in: place?.timeZone ?? .current)
    }

    var isShowingToday: Bool { selectedDate == today }

    func select(_ place: ActivePlace) {
        let wasToday = isShowingToday
        settings.activePlace = place
        if wasToday { selectedDate = today }
    }

    /// Uses the GPS position as active place. The name and time zone come from reverse geocoding when the
    /// network is available; otherwise the device time zone is used, which is right for the place the
    /// device is in when the system time zone is set automatically.
    func useCurrentLocation() async {
        locationError = nil
        do {
            let location = try await location.requestCurrentLocation()
            guard let coordinate = GeoCoordinate(latitude: location.coordinate.latitude,
                                                 longitude: location.coordinate.longitude) else { return }
            let geocoded = try? await PlaceGeocoder.reverse(coordinate)
            select(ActivePlace(
                name: geocoded?.name ?? "Position actuelle",
                subtitle: geocoded?.subtitle ?? ActivePlace.format(coordinate),
                coordinate: coordinate,
                timeZone: geocoded?.timeZone ?? .current,
                timeZoneIsEstimated: false,
                source: .currentLocation
            ))
        } catch {
            locationError = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func clearLocationError() {
        locationError = nil
    }

    /// Recomputes and schedules all local notifications.
    func replanNotifications(context: ModelContext) async {
        let now = Date.now
        let descriptor = FetchDescriptor<PhotoSession>(
            predicate: #Predicate { $0.start > now },
            sortBy: [SortDescriptor(\.start)]
        )
        let sessions = ((try? context.fetch(descriptor)) ?? []).compactMap(\.plannerInput)
        let planner = NotificationPlanner()
        let plan = planner.plan(
            now: now,
            solarAlerts: settings.solarNotificationsEnabled ? settings.solarAlerts : [],
            solarOffset: settings.solarAlertOffset,
            place: place?.alertPlace,
            sessions: sessions
        )
        await notifications.apply(plan, hourCycle: settings.hourCycle, now: now)
    }
}

enum AppTab: Hashable {
    case today
    case calendar
    case compass
    case sessions
    case settings
}
