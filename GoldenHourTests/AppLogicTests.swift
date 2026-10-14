import SwiftData
import XCTest
import SolarEngine
import GoldenHourCore
@testable import GoldenHour

final class AppSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "GoldenHourTests.settings"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    func testDefaults() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.hourCycle, .system)
        XCTAssertEqual(settings.theme, .system)
        XCTAssertFalse(settings.solarNotificationsEnabled)
        XCTAssertEqual(settings.solarAlerts, [.goldenHourStart])
        XCTAssertEqual(settings.solarAlertOffset, .fifteen)
        XCTAssertNil(settings.activePlace)
    }

    func testValuesArePersisted() {
        let settings = AppSettings(defaults: defaults)
        settings.hourCycle = .twelveHour
        settings.theme = .dark
        settings.solarNotificationsEnabled = true
        settings.solarAlerts = [.sunset, .blueHourStart]
        settings.solarAlertOffset = .atEvent
        let place = ActivePlace(
            name: "Tokyo", subtitle: "Japon",
            coordinate: GeoCoordinate(latitude: 35.6762, longitude: 139.6503)!,
            timeZone: TimeZone(identifier: "Asia/Tokyo")!, timeZoneIsEstimated: false, source: .manual
        )
        settings.activePlace = place

        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.hourCycle, .twelveHour)
        XCTAssertEqual(reloaded.theme, .dark)
        XCTAssertTrue(reloaded.solarNotificationsEnabled)
        XCTAssertEqual(reloaded.solarAlerts, [.sunset, .blueHourStart])
        XCTAssertEqual(reloaded.solarAlertOffset, .atEvent)
        XCTAssertEqual(reloaded.activePlace, place)
    }
}

@MainActor
final class PersistenceTests: XCTestCase {
    func testSessionRoundTripAndPlannerInput() throws {
        let container = try ModelContainer(
            for: SavedPlace.self, PhotoSession.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let context = container.mainContext
        let place = ActivePlace(
            name: "Paris", subtitle: "",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)!,
            timeZone: TimeZone(identifier: "Europe/Paris")!, timeZoneIsEstimated: false, source: .manual
        )
        let start = Date(timeIntervalSince1970: 1_800_000_000)
        context.insert(PhotoSession(title: "Test", start: start, place: place, anchor: .eveningGoldenHour, reminder: .ten))
        context.insert(PhotoSession(title: "Sans rappel", start: start, place: nil, anchor: .customTime, reminder: nil))
        try context.save()

        let sessions = try context.fetch(FetchDescriptor<PhotoSession>(sortBy: [SortDescriptor(\.title)]))
        XCTAssertEqual(sessions.count, 2)
        let withPlace = try XCTUnwrap(sessions.first { $0.title == "Test" })
        XCTAssertEqual(withPlace.anchor, .eveningGoldenHour)
        XCTAssertEqual(withPlace.reminder, .ten)
        XCTAssertEqual(withPlace.timeZone.identifier, "Europe/Paris")
        let input = try XCTUnwrap(withPlace.plannerInput)
        XCTAssertEqual(input.anchor, .solarEvent(.eveningGoldenHourStart))
        XCTAssertEqual(input.place?.name, "Paris")

        let without = try XCTUnwrap(sessions.first { $0.title == "Sans rappel" })
        XCTAssertNil(without.plannerInput, "no reminder → nothing to schedule")
        XCTAssertNil(without.place)
    }

    func testSavedPlaceProducesActivePlace() throws {
        let saved = SavedPlace(
            name: "Reykjavik", subtitle: "Islande",
            coordinate: GeoCoordinate(latitude: 64.1466, longitude: -21.9426)!,
            timeZone: TimeZone(identifier: "Atlantic/Reykjavik")!, timeZoneIsEstimated: false
        )
        let active = try XCTUnwrap(saved.activePlace)
        XCTAssertEqual(active.source, .saved(saved.id))
        XCTAssertEqual(active.timeZoneIdentifier, "Atlantic/Reykjavik")
    }
}

final class AnchorAndTextTests: XCTestCase {
    func testEveryAnchorExceptCustomMapsToAnEvent() {
        for anchor in SessionLightAnchor.allCases {
            if anchor == .customTime {
                XCTAssertNil(anchor.eventKind)
                XCTAssertEqual(anchor.sessionAnchor, .startTime)
            } else {
                XCTAssertNotNil(anchor.eventKind, "\(anchor)")
            }
        }
        XCTAssertEqual(SessionLightAnchor.eveningBlueHour.eventKind, .eveningGoldenHourEnd)
    }

    func testNotificationTexts() {
        let zone = TimeZone(identifier: "Europe/Paris")!
        let event = Date(timeIntervalSince1970: 1_782_071_872) // 21:57 in Paris
        let solar = PlannedNotification(
            identifier: "solar.x", fireDate: event.addingTimeInterval(-900), eventDate: event,
            offset: .fifteen, timeZone: zone, content: .solar(kind: .sunset, placeName: "Paris")
        )
        let content = NotificationText.content(for: solar, hourCycle: .twentyFourHour)
        XCTAssertEqual(content.title, "Coucher du soleil dans 15 min")
        XCTAssertTrue(content.body.hasPrefix("Paris · "))
        XCTAssertTrue(content.body.contains("21:57"), content.body)

        let session = PlannedNotification(
            identifier: "session.y", fireDate: event, eventDate: event, offset: .atEvent, timeZone: zone,
            content: .session(sessionID: "y", title: "Trocadéro", placeName: "Paris", anchor: .solarEvent(.sunset))
        )
        let sessionContent = NotificationText.content(for: session, hourCycle: .twentyFourHour)
        XCTAssertEqual(sessionContent.title, "Trocadéro")
        XCTAssertTrue(sessionContent.body.hasPrefix("Coucher du soleil · "), sessionContent.body)
    }

    func testLightStatusCacheReturnsSameValueUntilBoundary() throws {
        let place = ActivePlace(
            name: "Paris", subtitle: "",
            coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)!,
            timeZone: TimeZone(identifier: "Europe/Paris")!, timeZoneIsEstimated: false, source: .manual
        )
        let cache = LightStatusCache()
        let noon = LocalDate(year: 2026, month: 6, day: 21)!.startOfDay(in: place.timeZone).addingTimeInterval(12 * 3600)
        let a = cache.status(at: noon, place: place)
        let b = cache.status(at: noon.addingTimeInterval(30), place: place)
        XCTAssertEqual(a.date, b.date, "cached value reused")
        let next = try XCTUnwrap(a.nextPeriod)
        let c = cache.status(at: next.start.addingTimeInterval(1), place: place)
        XCTAssertEqual(c.currentPeriod?.start, next.start, "recomputed after the boundary")
    }
}
