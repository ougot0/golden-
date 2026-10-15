import SwiftData
import SwiftUI
import SolarEngine
import GoldenHourCore

/// Day / week / month navigation through solar times.
struct SolarCalendarView: View {
    enum Scale: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var title: String {
            switch self {
            case .day: return "Jour"
            case .week: return "Semaine"
            case .month: return "Mois"
            }
        }
    }

    @Environment(AppModel.self) private var model
    @Environment(AppSettings.self) private var settings
    @Query(sort: \PhotoSession.start) private var sessions: [PhotoSession]
    @State private var scale: Scale = .month
    @State private var focus: LocalDate?
    @State private var days: [SolarDay] = []
    @State private var showingDatePicker = false
    @State private var showingPlacePicker = false
    @State private var newSessionDate: LocalDate?

    var body: some View {
        NavigationStack {
            Group {
                if let place = model.place {
                    content(place: place)
                } else {
                    ScrollView {
                        StatusMessage(
                            systemImage: "mappin.slash",
                            title: "Aucun lieu sélectionné",
                            message: "Le calendrier affiche les heures du soleil pour un lieu. Choisissez-en un pour commencer.",
                            actionTitle: "Choisir un lieu",
                            action: { showingPlacePicker = true }
                        )
                        .padding(20)
                    }
                }
            }
            .instrumentBackground()
            .navigationTitle("Calendrier")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: LocalDate.self) { date in
                DayDetailView(date: date)
            }
            .sheet(isPresented: $showingPlacePicker) { PlacePickerView() }
            .sheet(item: $newSessionDate) { date in
                SessionEditorView(session: nil, initialDate: date)
            }
        }
    }

    private var currentFocus: LocalDate { focus ?? model.selectedDate }

    @ViewBuilder
    private func content(place: ActivePlace) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 12) {
                Picker("Échelle", selection: $scale) {
                    ForEach(Scale.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)

                HStack {
                    Button { move(-1) } label: {
                        Image(systemName: "chevron.left").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Précédent")
                    Button { showingDatePicker = true } label: {
                        Text(periodTitle(place: place))
                            .font(.headline)
                            .foregroundStyle(Palette.ink)
                            .frame(maxWidth: .infinity)
                    }
                    .accessibilityHint("Choisir une date")
                    Button { move(1) } label: {
                        Image(systemName: "chevron.right").frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Suivant")
                }
                .foregroundStyle(Palette.amberText)

                if currentFocus != model.today {
                    Button("Revenir à aujourd'hui") { focus = model.today }
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)

            Hairline()

            ScrollView {
                Group {
                    switch scale {
                    case .month: MonthGrid(focus: currentFocus, days: days, today: model.today, sessions: sessionDates(place: place)) { focus = $0 }
                    case .week: WeekList(days: days, today: model.today)
                    case .day: dayContent(place: place)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)

                if scale == .month, let selected = days.first(where: { $0.date == currentFocus }) {
                    DaySummary(day: selected, sessions: sessionsOn(selected), onPlan: { newSessionDate = selected.date })
                        .padding(.horizontal, 20)
                        .padding(.bottom, 24)
                }
            }
        }
        .task(id: TaskKey(focus: currentFocus, scale: scale, place: place)) {
            days = await compute(place: place)
        }
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(date: Binding(get: { currentFocus }, set: { focus = $0 }), timeZone: place.timeZone)
        }
    }

    @ViewBuilder
    private func dayContent(place: ActivePlace) -> some View {
        if let day = days.first(where: { $0.date == currentFocus }) {
            VStack(alignment: .leading, spacing: 24) {
                SessionsOfDay(sessions: sessionsOn(day), onPlan: { newSessionDate = day.date })
                SolarDayDetailSections(day: day, now: day.date == model.today ? .now : nil)
            }
        } else {
            ProgressView().frame(maxWidth: .infinity)
        }
    }

    private struct TaskKey: Equatable {
        let focus: LocalDate
        let scale: Scale
        let place: ActivePlace
    }

    /// Dates displayed for the current scale.
    private func visibleDates(place: ActivePlace) -> [LocalDate] {
        let focus = currentFocus
        switch scale {
        case .day:
            return [focus]
        case .week:
            let start = startOfWeek(focus, place: place)
            return (0..<7).map { start.adding(days: $0) }
        case .month:
            let first = LocalDate(year: focus.year, month: focus.month, day: 1)!
            let start = startOfWeek(first, place: place)
            return (0..<42).map { start.adding(days: $0) }
        }
    }

    private func startOfWeek(_ date: LocalDate, place: ActivePlace) -> LocalDate {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = place.timeZone
        calendar.firstWeekday = Calendar.current.firstWeekday
        let noon = date.startOfDay(in: place.timeZone).addingTimeInterval(12 * 3600)
        let weekday = calendar.component(.weekday, from: noon)
        let delta = (weekday - calendar.firstWeekday + 7) % 7
        return date.adding(days: -delta)
    }

    private func compute(place: ActivePlace) async -> [SolarDay] {
        let dates = visibleDates(place: place)
        let coordinate = place.coordinate
        let zone = place.timeZone
        return await Task.detached(priority: .userInitiated) {
            dates.map { SolarDayCalculator.solarDay(for: $0, coordinate: coordinate, timeZone: zone) }
        }.value
    }

    private func move(_ direction: Int) {
        let focus = currentFocus
        var next: LocalDate
        switch scale {
        case .day: next = focus.adding(days: direction)
        case .week: next = focus.adding(days: 7 * direction)
        case .month:
            var month = focus.month + direction
            var year = focus.year
            if month < 1 { month = 12; year -= 1 }
            if month > 12 { month = 1; year += 1 }
            let day = min(focus.day, 28)
            next = LocalDate(year: year, month: month, day: day)!
        }
        next = min(max(next, SupportedDates.lowerBound), SupportedDates.upperBound)
        self.focus = next
    }

    private func periodTitle(place: ActivePlace) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = place.timeZone
        let noon = currentFocus.startOfDay(in: place.timeZone).addingTimeInterval(12 * 3600)
        switch scale {
        case .day:
            formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMMyyyy")
            return formatter.string(from: noon)
        case .week:
            let start = startOfWeek(currentFocus, place: place)
            formatter.setLocalizedDateFormatFromTemplate("dMMM")
            let a = formatter.string(from: start.startOfDay(in: place.timeZone).addingTimeInterval(12 * 3600))
            let b = formatter.string(from: start.adding(days: 6).startOfDay(in: place.timeZone).addingTimeInterval(12 * 3600))
            return "\(a) – \(b)"
        case .month:
            formatter.setLocalizedDateFormatFromTemplate("MMMMyyyy")
            return formatter.string(from: noon).capitalizingFirstLetter
        }
    }

    private func sessionsOn(_ day: SolarDay) -> [PhotoSession] {
        sessions.filter { day.interval.contains($0.start) && $0.start < day.interval.end }
    }

    private func sessionDates(place: ActivePlace) -> Set<LocalDate> {
        Set(sessions.map { LocalDate($0.start, in: place.timeZone) })
    }
}

// MARK: - Month

private struct MonthGrid: View {
    let focus: LocalDate
    let days: [SolarDay]
    let today: LocalDate
    let sessions: Set<LocalDate>
    let onSelect: (LocalDate) -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
        LazyVGrid(columns: columns, spacing: 2) {
            ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Palette.inkSecondary)
                    .frame(maxWidth: .infinity)
                    .accessibilityHidden(true)
            }
            ForEach(days, id: \.date) { day in
                cell(day)
            }
        }
    }

    private var weekdaySymbols: [String] {
        let calendar = Calendar.current
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }

    private func cell(_ day: SolarDay) -> some View {
        let inMonth = day.date.month == focus.month
        let isFocus = day.date == focus
        let isToday = day.date == today
        let formatter = SolarTimeFormatter(timeZone: day.timeZone, hourCycle: settings.hourCycle)
        let golden = day.eveningGoldenHour?.start ?? day.goldenHours.last?.start
        return Button {
            onSelect(day.date)
        } label: {
            VStack(spacing: 3) {
                Text("\(day.date.day)")
                    .font(.callout.weight(isToday ? .bold : .regular))
                    .foregroundStyle(isFocus ? Color(hex: 0x151717) : (inMonth ? Palette.ink : Palette.inkSecondary))
                Text(golden.map { formatter.time($0) } ?? "—")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(isFocus ? Color(hex: 0x151717) : Palette.inkSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Circle()
                    .fill(sessions.contains(day.date) ? (isFocus ? Color(hex: 0x151717) : Palette.amber) : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .background(isFocus ? Palette.amber : .clear)
            .overlay(alignment: .top) {
                if isToday && !isFocus { Rectangle().fill(Palette.amber).frame(height: 2) }
            }
            .opacity(inMonth ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel(day, golden: golden, formatter: formatter))
        .accessibilityAddTraits(isFocus ? .isSelected : [])
    }

    private func accessibilityLabel(_ day: SolarDay, golden: Date?, formatter: SolarTimeFormatter) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.timeZone = day.timeZone
        dateFormatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        var text = dateFormatter.string(from: day.interval.start.addingTimeInterval(12 * 3600))
        if let golden { text += ", heure dorée du soir à \(formatter.time(golden))" }
        if sessions.contains(day.date) { text += ", séance planifiée" }
        return text
    }
}

private struct DaySummary: View {
    let day: SolarDay
    let sessions: [PhotoSession]
    let onPlan: () -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let times = DayTimeFormatter(day: day, hourCycle: settings.hourCycle)
        VStack(alignment: .leading, spacing: 12) {
            Hairline()
            Text("Sous chaque jour : début de l'heure dorée du soir.")
                .font(.caption)
                .foregroundStyle(Palette.inkSecondary)
            ValueRow(label: "Lever · Coucher", value: "\(times.time(day.sunrise)) · \(times.time(day.sunset))")
            ValueRow(label: "Heure dorée du matin", value: times.range(day.morningGoldenHour), emphasized: true)
            ValueRow(label: "Heure dorée du soir", value: times.range(day.eveningGoldenHour), emphasized: true)
            ValueRow(label: "Heure bleue du soir", value: times.range(day.eveningBlueHour))
            SessionsOfDay(sessions: sessions, onPlan: onPlan)
            NavigationLink(value: day.date) {
                Label("Détail de la journée", systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Palette.amberText)
        }
    }
}

private struct SessionsOfDay: View {
    let sessions: [PhotoSession]
    let onPlan: () -> Void
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sessions) { session in
                NavigationLink {
                    SessionDetailView(session: session)
                } label: {
                    HStack {
                        Image(systemName: "camera.aperture").foregroundStyle(Palette.amberText)
                        Text(session.title).foregroundStyle(Palette.ink)
                        Spacer()
                        Text(SolarTimeFormatter(timeZone: session.timeZone, hourCycle: settings.hourCycle).time(session.start))
                            .monospacedDigit()
                            .foregroundStyle(Palette.inkSecondary)
                    }
                }
            }
            Button(action: onPlan) {
                Label("Planifier une séance ce jour-là", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(Palette.amberText)
        }
    }
}

// MARK: - Week

private struct WeekList: View {
    let days: [SolarDay]
    let today: LocalDate
    @Environment(AppSettings.self) private var settings

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(days, id: \.date) { day in
                let times = DayTimeFormatter(day: day, hourCycle: settings.hourCycle)
                NavigationLink(value: day.date) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(title(day))
                                .font(.headline)
                                .foregroundStyle(day.date == today ? Palette.amberText : Palette.ink)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Palette.inkSecondary)
                        }
                        Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 4) {
                            GridRow {
                                Text("Soleil").foregroundStyle(Palette.inkSecondary)
                                Text("\(times.time(day.sunrise)) – \(times.time(day.sunset))").monospacedDigit()
                            }
                            GridRow {
                                Text("Dorée matin").foregroundStyle(Palette.inkSecondary)
                                Text(times.range(day.morningGoldenHour)).monospacedDigit()
                            }
                            GridRow {
                                Text("Dorée soir").foregroundStyle(Palette.inkSecondary)
                                Text(times.range(day.eveningGoldenHour)).monospacedDigit()
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(Palette.ink)
                    }
                    .padding(.vertical, 12)
                }
                .buttonStyle(.plain)
                Hairline()
            }
        }
    }

    private func title(_ day: SolarDay) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = day.timeZone
        formatter.setLocalizedDateFormatFromTemplate("EEEEdMMMM")
        return formatter.string(from: day.interval.start.addingTimeInterval(12 * 3600)).capitalizingFirstLetter
    }
}

// MARK: - Day detail

struct DayDetailView: View {
    let date: LocalDate
    @Environment(AppModel.self) private var model

    var body: some View {
        ScrollView {
            if let place = model.place {
                let day = SolarDayCalculator.solarDay(for: date, coordinate: place.coordinate, timeZone: place.timeZone)
                SolarDayDetailSections(day: day, now: date == model.today ? .now : nil)
                    .padding(20)
            }
        }
        .instrumentBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        let zone = model.place?.timeZone ?? .current
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.setLocalizedDateFormatFromTemplate("EEEdMMMyyyy")
        return formatter.string(from: date.startOfDay(in: zone).addingTimeInterval(12 * 3600))
    }
}
