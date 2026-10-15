import SwiftUI
import SolarEngine
import GoldenHourCore

struct DashboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @State private var showingPlacePicker = false
    @State private var showingDatePicker = false
    @State private var statusCache = LightStatusCache()

    var body: some View {
        NavigationStack {
            ScrollView {
                if let place = model.place {
                    content(place: place)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 32)
                } else {
                    NoPlaceView(showPlacePicker: { showingPlacePicker = true })
                        .padding(20)
                }
            }
            .instrumentBackground()
            .navigationTitle("Aujourd'hui")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showingPlacePicker = true
                    } label: {
                        Label(model.place?.name ?? "Choisir un lieu", systemImage: "mappin.and.ellipse")
                            .labelStyle(.titleAndIcon)
                    }
                    .accessibilityIdentifier("placeButton")
                }
            }
            .sheet(isPresented: $showingPlacePicker) {
                PlacePickerView()
            }
            .sheet(isPresented: $showingDatePicker) {
                DatePickerSheet(date: Binding(
                    get: { model.selectedDate },
                    set: { model.selectedDate = $0 }
                ), timeZone: model.place?.timeZone ?? .current)
            }
        }
    }

    @ViewBuilder
    private func content(place: ActivePlace) -> some View {
        let day = SolarDayCalculator.solarDay(for: model.selectedDate, coordinate: place.coordinate, timeZone: place.timeZone)
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 4) {
                PlaceHeader(place: place, action: { showingPlacePicker = true })
                DateNavigator(
                    date: model.selectedDate,
                    timeZone: place.timeZone,
                    isToday: model.isShowingToday,
                    onPrevious: { model.selectedDate = model.selectedDate.adding(days: -1) },
                    onNext: { model.selectedDate = model.selectedDate.adding(days: 1) },
                    onToday: { model.selectedDate = model.today },
                    onPick: { showingDatePicker = true }
                )
            }
            .padding(.top, 8)

            if place.timeZoneIsEstimated {
                StatusMessage(
                    systemImage: "clock.badge.questionmark",
                    title: "Fuseau horaire à confirmer",
                    message: "Le fuseau de ce lieu n'a pas pu être déterminé ; celui de l'appareil (\(place.timeZoneIdentifier)) est utilisé. Vérifiez-le dans la fiche du lieu.",
                    actionTitle: "Modifier le lieu",
                    action: { showingPlacePicker = true }
                )
            }

            if model.isShowingToday {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    LiveSection(
                        now: context.date,
                        place: place,
                        status: statusCache.status(at: context.date, place: place)
                    )
                }
            }

            if model.isShowingToday {
                TimelineView(.everyMinute) { context in
                    SolarDayDetailSections(day: day, now: context.date)
                }
            } else {
                SolarDayDetailSections(day: day, now: nil)
            }

            PlaceFooter(place: place)
        }
    }
}

/// Countdown and live sun position, refreshed every second.
private struct LiveSection: View {
    let now: Date
    let place: ActivePlace
    let status: LightStatus
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let formatter = SolarTimeFormatter(timeZone: place.timeZone, hourCycle: settings.hourCycle)
        let position = SolarCalculator.position(at: now, coordinate: place.coordinate)
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                if let current = status.currentPeriod {
                    InstrumentLabel("En cours · \(SolarStrings.period(current))")
                    Text(DurationFormatting.countdown(current.end.timeIntervalSince(now)))
                        .font(.system(.largeTitle, design: .default, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(Palette.amberText)
                        .accessibilityLabel("Se termine dans \(DurationFormatting.hoursMinutes(current.end.timeIntervalSince(now)))")
                    Text("Fin à \(formatter.time(current.end))")
                        .font(.subheadline).monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                } else if let next = status.nextPeriod {
                    InstrumentLabel("\(SolarStrings.period(next)) dans")
                    Text(DurationFormatting.countdown(next.start.timeIntervalSince(now)))
                        .font(.system(.largeTitle, design: .default, weight: .light))
                        .monospacedDigit()
                        .foregroundStyle(Palette.ink)
                        .accessibilityLabel("Commence dans \(DurationFormatting.hoursMinutes(next.start.timeIntervalSince(now)))")
                    Text(nextDescription(next, formatter: formatter))
                        .font(.subheadline).monospacedDigit()
                        .foregroundStyle(Palette.inkSecondary)
                } else {
                    InstrumentLabel("Prochaine période")
                    Text("Aucune heure dorée ni heure bleue dans les \(status.searchedDays) prochains jours à ce lieu.")
                        .font(.subheadline)
                        .foregroundStyle(Palette.inkSecondary)
                }
                Text("Lumière actuelle : \(SolarStrings.phase(status.phase).lowercased())")
                    .font(.footnote)
                    .foregroundStyle(Palette.inkSecondary)
            }
            .accessibilityElement(children: .combine)

            InstrumentSection(title: "Position du soleil") {
                HStack(alignment: .firstTextBaseline, spacing: 24) {
                    reading(title: "Azimut",
                            value: AngleFormatting.degrees(position.azimuth),
                            detail: CompassMath.cardinalAbbreviation(for: position.azimuth))
                    reading(title: "Élévation",
                            value: AngleFormatting.degrees(position.apparentElevation),
                            detail: position.elevation > -1 ? "avec réfraction" : "sous l'horizon")
                }
            }
        }
    }

    private func nextDescription(_ period: LightPeriod, formatter: SolarTimeFormatter) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        let range = "\(formatter.time(period.start)) – \(period.endIsOpen ? "après " : "")\(formatter.time(period.end))"
        if calendar.isDate(period.start, inSameDayAs: now) {
            return range
        }
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = place.timeZone
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return "\(dateFormatter.string(from: period.start)), \(range)"
    }

    private func reading(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption).foregroundStyle(Palette.inkSecondary)
            Text(value).font(.title2.weight(.regular)).monospacedDigit().foregroundStyle(Palette.ink)
            Text(detail).font(.caption).foregroundStyle(Palette.inkSecondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Avoids recomputing the light status every second: the cached value stays valid until the current
/// period ends or the next one starts.
final class LightStatusCache {
    private var cached: LightStatus?
    private var cachedPlace: ActivePlace?
    private var validUntil: Date = .distantPast

    func status(at date: Date, place: ActivePlace) -> LightStatus {
        if let cached, cachedPlace == place, date < validUntil, date >= cached.date {
            return cached
        }
        let status = LightForecast.status(at: date, coordinate: place.coordinate, timeZone: place.timeZone)
        var limit = date.addingTimeInterval(3600)
        if let end = status.currentPeriod?.end { limit = min(limit, end) }
        if let start = status.nextPeriod?.start { limit = min(limit, start) }
        cached = status
        cachedPlace = place
        validUntil = limit
        return status
    }
}

/// Name of the active place, always visible at the top of the dashboard; tapping it changes the place.
private struct PlaceHeader: View {
    let place: ActivePlace
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: place.source == .currentLocation ? "location.fill" : "mappin.and.ellipse")
                    .font(.subheadline)
                Text(place.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(Palette.amberText)
            .frame(minHeight: 44, alignment: .leading)
            .padding(.leading, 12)
        }
        .accessibilityLabel("Lieu : \(place.name)")
        .accessibilityHint("Changer de lieu")
        .accessibilityIdentifier("placeHeader")
    }
}

struct DateNavigator: View {
    let date: LocalDate
    let timeZone: TimeZone
    let isToday: Bool
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onToday: () -> Void
    let onPick: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onPrevious) {
                Image(systemName: "chevron.left").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Jour précédent")
            .disabled(date <= SupportedDates.lowerBound)

            Button(action: onPick) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Palette.ink)
                    Text(isToday ? "Aujourd'hui" : "Toucher pour choisir une date")
                        .font(.caption)
                        .foregroundStyle(Palette.inkSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .accessibilityHint("Choisir une date")
            .accessibilityIdentifier("dateButton")

            if !isToday {
                Button("Aujourd'hui", action: onToday)
                    .font(.subheadline.weight(.semibold))
            }

            Button(action: onNext) {
                Image(systemName: "chevron.right").frame(width: 44, height: 44)
            }
            .accessibilityLabel("Jour suivant")
            .disabled(date >= SupportedDates.upperBound)
        }
        .foregroundStyle(Palette.amberText)
    }

    private var title: String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
        return formatter.string(from: date.startOfDay(in: timeZone).addingTimeInterval(12 * 3600)).capitalizingFirstLetter
    }
}

/// Range of dates offered in the UI. The algorithm itself stays accurate well beyond, but ΔT and the
/// time-zone database are only meaningful over a limited period.
enum SupportedDates {
    static let lowerBound = LocalDate(year: 1900, month: 1, day: 1)!
    static let upperBound = LocalDate(year: 2100, month: 12, day: 31)!

    static func range(in timeZone: TimeZone) -> ClosedRange<Date> {
        lowerBound.startOfDay(in: timeZone)...upperBound.startOfDay(in: timeZone)
    }
}

struct DatePickerSheet: View {
    @Binding var date: LocalDate
    let timeZone: TimeZone
    @Environment(\.dismiss) private var dismiss
    @State private var selection = Date.now

    var body: some View {
        NavigationStack {
            DatePicker("Date", selection: $selection, in: SupportedDates.range(in: timeZone), displayedComponents: .date)
                .datePickerStyle(.graphical)
                .environment(\.timeZone, timeZone)
                .padding()
                .navigationTitle("Choisir une date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Annuler") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Valider") {
                            date = LocalDate(selection, in: timeZone)
                            dismiss()
                        }
                    }
                }
        }
        .presentationDetents([.medium, .large])
        .onAppear {
            selection = date.startOfDay(in: timeZone).addingTimeInterval(12 * 3600)
        }
    }
}

private struct NoPlaceView: View {
    let showPlacePicker: () -> Void

    var body: some View {
        StatusMessage(
            systemImage: "mappin.slash",
            title: "Aucun lieu sélectionné",
            message: "Choisissez un lieu pour calculer les heures du soleil : votre position actuelle, une recherche ou des coordonnées. Les calculs se font ensuite sur l'appareil, sans connexion.",
            actionTitle: "Choisir un lieu",
            action: showPlacePicker
        )
    }
}

private struct PlaceFooter: View {
    let place: ActivePlace

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Hairline()
            Text(place.formattedCoordinate)
            Text("Fuseau : \(place.timeZoneIdentifier)")
            Text("Heures exprimées dans l'heure locale du lieu.")
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(Palette.inkSecondary)
    }
}
