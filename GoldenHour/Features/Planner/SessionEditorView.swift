import SwiftData
import SwiftUI
import UserNotifications
import SolarEngine
import GoldenHourCore

/// Creates or edits a photo session.
struct SessionEditorView: View {
    /// `nil` to create a new session.
    let session: PhotoSession?
    let initialDate: LocalDate

    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SavedPlace.name) private var savedPlaces: [SavedPlace]

    @State private var title = ""
    @State private var notes = ""
    @State private var place: ActivePlace?
    @State private var day = Date.now
    @State private var customTime = Date.now
    @State private var anchor: SessionLightAnchor = .eveningGoldenHour
    @State private var reminder: ReminderOffset? = .thirty
    @State private var loaded = false
    @State private var notificationWarning: String?

    private var timeZone: TimeZone { place?.timeZone ?? .current }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Titre", text: $title)
                        .accessibilityIdentifier("sessionTitle")
                }

                Section("Lieu") {
                    Picker("Lieu", selection: placeSelection) {
                        Text("Aucun").tag(PlaceChoice.noPlace)
                        if let place, !isKnown(place) {
                            Text(place.name).tag(PlaceChoice.current)
                        }
                        if let active = model.place {
                            Text("\(active.name) (lieu actuel)").tag(PlaceChoice.active)
                        }
                        ForEach(savedPlaces) { saved in
                            Text(saved.name).tag(PlaceChoice.saved(saved.id))
                        }
                    }
                    if let place {
                        Text("\(place.formattedCoordinate) · \(place.timeZoneIdentifier)")
                            .font(.caption).monospacedDigit()
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }

                Section {
                    DatePicker("Date", selection: $day, in: SupportedDates.range(in: timeZone), displayedComponents: .date)
                    Picker("Lumière", selection: $anchor) {
                        ForEach(SessionLightAnchor.allCases) { Text($0.title).tag($0) }
                    }
                    if anchor == .customTime {
                        DatePicker("Heure", selection: $customTime, displayedComponents: .hourAndMinute)
                    } else {
                        anchorPreview
                    }
                } header: {
                    Text("Moment")
                } footer: {
                    Text("Les heures sont celles du lieu (\(timeZone.identifier)).")
                }
                .environment(\.timeZone, timeZone)

                Section {
                    Picker("Rappel", selection: $reminder) {
                        Text("Aucun").tag(ReminderOffset?.none)
                        ForEach(ReminderOffset.allCases) { offset in
                            Text(SolarStrings.reminder(offset)).tag(Optional(offset))
                        }
                    }
                    if let notificationWarning {
                        Text(notificationWarning).font(.footnote).foregroundStyle(Palette.warning)
                    }
                } header: {
                    Text("Rappel")
                }

                Section("Notes") {
                    TextField("Matériel, cadrage, accès…", text: $notes, axis: .vertical)
                        .lineLimit(3...10)
                }
            }
            .navigationTitle(session == nil ? "Nouvelle séance" : "Modifier la séance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Annuler") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enregistrer") { save() }
                        .disabled(!canSave)
                        .accessibilityIdentifier("saveSession")
                }
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Place selection

    private enum PlaceChoice: Hashable {
        case noPlace
        /// The session's own place, when it is neither a favourite nor the active place.
        case current
        case active
        case saved(UUID)
    }

    private func isKnown(_ place: ActivePlace) -> Bool {
        savedPlaces.contains { matches($0, place) } || model.place?.coordinate == place.coordinate
    }

    private var placeSelection: Binding<PlaceChoice> {
        Binding(
            get: {
                guard let place else { return .noPlace }
                if let saved = savedPlaces.first(where: { matches($0, place) }) { return .saved(saved.id) }
                if let active = model.place, active.coordinate == place.coordinate { return .active }
                return .current
            },
            set: { choice in
                let previousZone = timeZone
                switch choice {
                case .noPlace: place = nil
                case .current: break
                case .active: place = model.place
                case .saved(let id): place = savedPlaces.first { $0.id == id }?.activePlace
                }
                // Keep the same calendar day when the time zone changes.
                let local = LocalDate(day, in: previousZone)
                day = local.startOfDay(in: timeZone).addingTimeInterval(12 * 3600)
            }
        )
    }

    private func matches(_ saved: SavedPlace, _ place: ActivePlace) -> Bool {
        abs(saved.latitude - place.coordinate.latitude) < 1e-6 && abs(saved.longitude - place.coordinate.longitude) < 1e-6
    }

    // MARK: Anchor

    private var anchorEventDate: Date? {
        guard let kind = anchor.eventKind, let place else { return nil }
        let solarDay = SolarDayCalculator.solarDay(for: LocalDate(day, in: timeZone), coordinate: place.coordinate, timeZone: timeZone)
        return solarDay.event(kind)?.date
    }

    @ViewBuilder
    private var anchorPreview: some View {
        if place == nil {
            Text("Choisissez un lieu pour caler la séance sur la lumière.")
                .font(.footnote).foregroundStyle(Palette.warning)
        } else if let date = anchorEventDate {
            LabeledContent("Début", value: SolarTimeFormatter(timeZone: timeZone, hourCycle: settings.hourCycle).time(date))
                .monospacedDigit()
        } else {
            Text("Ce moment n'existe pas ce jour-là à ce lieu (soleil trop haut ou trop bas). Choisissez une autre lumière ou une heure personnalisée.")
                .font(.footnote).foregroundStyle(Palette.warning)
        }
    }

    private var resolvedStart: Date? {
        if anchor == .customTime {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = timeZone
            let time = calendar.dateComponents([.hour, .minute], from: customTime)
            let local = LocalDate(day, in: timeZone)
            return calendar.date(from: DateComponents(
                year: local.year, month: local.month, day: local.day, hour: time.hour, minute: time.minute
            ))
        }
        return anchorEventDate
    }

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty && resolvedStart != nil
    }

    // MARK: Load / save

    private func load() {
        guard !loaded else { return }
        loaded = true
        Task {
            await model.notifications.refreshAuthorization()
            if model.notifications.authorizationStatus == .denied {
                notificationWarning = "Les notifications de GoldenHour sont désactivées dans les Réglages d'iOS : aucun rappel ne s'affichera."
            }
        }
        if let session {
            title = session.title
            notes = session.notes
            place = session.place
            day = session.start
            customTime = session.start
            anchor = session.anchor
            reminder = session.reminder
        } else {
            place = model.place
            let zone = model.place?.timeZone ?? .current
            day = initialDate.startOfDay(in: zone).addingTimeInterval(12 * 3600)
            customTime = day.addingTimeInterval(6 * 3600)
        }
    }

    private func save() {
        guard let start = resolvedStart else { return }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if let session {
            session.title = trimmedTitle
            session.notes = notes
            session.start = start
            session.setPlace(place)
            session.anchor = anchor
            session.reminder = reminder
        } else {
            modelContext.insert(PhotoSession(
                title: trimmedTitle, start: start, notes: notes, place: place, anchor: anchor, reminder: reminder
            ))
        }
        try? modelContext.save()
        Task {
            if reminder != nil, model.notifications.authorizationStatus == .notDetermined {
                await model.notifications.requestAuthorization()
            }
            await model.replanNotifications(context: modelContext)
        }
        dismiss()
    }
}
