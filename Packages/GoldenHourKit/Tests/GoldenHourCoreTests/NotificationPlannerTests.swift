import XCTest
import SolarEngine
@testable import GoldenHourCore

final class NotificationPlannerTests: XCTestCase {
    let paris = AlertPlace(
        name: "Paris",
        coordinate: GeoCoordinate(latitude: 48.8566, longitude: 2.3522)!,
        timeZone: TimeZone(identifier: "Europe/Paris")!
    )
    // 2026-06-21 00:00 Paris time.
    lazy var now = LocalDate(year: 2026, month: 6, day: 21)!.startOfDay(in: paris.timeZone)

    func testSolarAlertsAreChronologicalOffsetAndInTheFuture() {
        let planner = NotificationPlanner(solarHorizonDays: 3)
        let plan = planner.plan(now: now, solarAlerts: [.goldenHourStart, .sunset], solarOffset: .fifteen,
                                place: paris, sessions: [])
        // 3 days × (2 golden hour starts + 1 sunset).
        XCTAssertEqual(plan.count, 9)
        XCTAssertEqual(plan.map(\.fireDate), plan.map(\.fireDate).sorted())
        for n in plan {
            XCTAssertGreaterThan(n.fireDate, now)
            XCTAssertEqual(n.eventDate.timeIntervalSince(n.fireDate), 15 * 60, accuracy: 0.001)
        }
        XCTAssertEqual(Set(plan.map(\.identifier)).count, plan.count, "identifiers must be unique")
    }

    func testIdentifiersAreStableAcrossReplanning() {
        let planner = NotificationPlanner(solarHorizonDays: 2)
        let a = planner.plan(now: now, solarAlerts: [.sunrise], solarOffset: .five, place: paris, sessions: [])
        let b = planner.plan(now: now.addingTimeInterval(60), solarAlerts: [.sunrise], solarOffset: .five, place: paris, sessions: [])
        XCTAssertEqual(a.map(\.identifier), b.map(\.identifier))
    }

    func testRespectsSystemLimitAndPrioritisesSessions() {
        let planner = NotificationPlanner(solarHorizonDays: 30)
        let sessions = (0..<10).map { i in
            SessionInput(id: "s\(i)", title: "Session \(i)", start: now.addingTimeInterval(Double(20 + i) * 86_400),
                         place: paris, anchor: .startTime, offset: .thirty)
        }
        let plan = planner.plan(now: now, solarAlerts: Set(SolarAlertKind.allCases), solarOffset: .ten,
                                place: paris, sessions: sessions)
        XCTAssertEqual(plan.count, NotificationPlanner.systemPendingLimit)
        // Sessions far in the future are kept even though many solar alerts come earlier.
        XCTAssertEqual(plan.filter { if case .session = $0.content { return true } else { return false } }.count, 10)
    }

    func testSessionAnchoredOnEveningGoldenHour() throws {
        let planner = NotificationPlanner()
        let sessionDay = LocalDate(year: 2026, month: 6, day: 23)!.startOfDay(in: paris.timeZone)
        let session = SessionInput(id: "x", title: "Pont Alexandre III", start: sessionDay.addingTimeInterval(20 * 3600),
                                   place: paris, anchor: .solarEvent(.eveningGoldenHourStart), offset: .sixty)
        let eventDate = try XCTUnwrap(planner.resolve(session))
        let day = SolarDayCalculator.solarDay(for: LocalDate(year: 2026, month: 6, day: 23)!,
                                              coordinate: paris.coordinate, timeZone: paris.timeZone)
        XCTAssertEqual(eventDate, day.event(.eveningGoldenHourStart)?.date)
        let plan = planner.plan(now: now, solarAlerts: [], solarOffset: .five, place: paris, sessions: [session])
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan[0].fireDate, eventDate.addingTimeInterval(-3600))
    }

    func testSessionAnchoredOnMissingEventIsNotScheduled() {
        let tromso = AlertPlace(name: "Tromsø", coordinate: GeoCoordinate(latitude: 69.6492, longitude: 18.9553)!,
                                timeZone: TimeZone(identifier: "Europe/Oslo")!)
        let start = LocalDate(year: 2026, month: 12, day: 21)!.startOfDay(in: tromso.timeZone).addingTimeInterval(12 * 3600)
        let session = SessionInput(id: "polar", title: "Nuit polaire", start: start, place: tromso,
                                   anchor: .solarEvent(.sunset), offset: .ten)
        let planner = NotificationPlanner()
        XCTAssertNil(planner.resolve(session))
        XCTAssertTrue(planner.plan(now: now, solarAlerts: [], solarOffset: .five, place: nil, sessions: [session]).isEmpty)
    }

    func testPastEventsAreSkipped() {
        let planner = NotificationPlanner()
        let session = SessionInput(id: "past", title: "Hier", start: now.addingTimeInterval(-3600), place: nil,
                                   anchor: .startTime, offset: .five)
        XCTAssertTrue(planner.plan(now: now, solarAlerts: [], solarOffset: .five, place: nil, sessions: [session]).isEmpty)
    }
}
