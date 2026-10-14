import SwiftUI
import SolarEngine
import GoldenHourCore

/// Sections describing one solar day: timeline, golden/blue hours, sun, twilights.
/// Shared by the dashboard and the calendar's day detail.
struct SolarDayDetailSections: View {
    let day: SolarDay
    var now: Date?
    @Environment(AppSettings.self) private var settings

    var body: some View {
        let times = DayTimeFormatter(day: day, hourCycle: settings.hourCycle)
        VStack(alignment: .leading, spacing: 28) {
            InstrumentSection(title: "Frise de la journée") {
                DayTimelineView(
                    day: day,
                    samples: SolarPath.samples(for: day.date, coordinate: day.coordinate, timeZone: day.timeZone),
                    now: now,
                    hourCycle: settings.hourCycle
                )
                PhaseLegend()
            }

            if let message = SolarStrings.condition(day.sunCondition) {
                Label(message, systemImage: day.sunCondition == .alwaysAbove ? "sun.max" : "moon.stars")
                    .font(.subheadline)
                    .foregroundStyle(Palette.ink)
            }

            InstrumentSection(title: "Heures dorées et bleues") {
                lightPeriods(times: times)
            }

            InstrumentSection(title: "Soleil") {
                ValueRow(label: "Lever", value: times.time(day.sunrise), emphasized: true)
                ValueRow(label: "Coucher", value: times.time(day.sunset), emphasized: true)
                ValueRow(
                    label: "Midi solaire",
                    value: times.time(day.solarNoon),
                    detail: day.event(.solarNoon).map { "élévation " + AngleFormatting.degrees($0.elevation) }
                )
                ValueRow(label: "Durée du jour", value: DurationFormatting.hoursMinutes(day.daylightDuration))
            }

            InstrumentSection(title: "Aubes et crépuscules") {
                twilightGrid(times: times)
            }
        }
    }

    @ViewBuilder
    private func lightPeriods(times: DayTimeFormatter) -> some View {
        let periods = (day.blueHours + day.goldenHours).sorted { $0.start < $1.start }
        if periods.isEmpty {
            Text("Aucune heure dorée ni heure bleue ce jour-là : le soleil reste \(day.maximumElevation < day.conventions.blueHourLower ? "trop bas" : "trop haut") toute la journée.")
                .font(.subheadline)
                .foregroundStyle(Palette.inkSecondary)
        } else {
            ForEach(periods, id: \.self) { period in
                ValueRow(
                    label: SolarStrings.period(period),
                    value: times.range(period),
                    detail: DurationFormatting.hoursMinutes(period.duration),
                    emphasized: period.phase == .goldenHour
                )
            }
        }
    }

    private func twilightGrid(times: DayTimeFormatter) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
            GridRow {
                Text("")
                Text("Aube").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
                    .gridColumnAlignment(.trailing)
                Text("Crépuscule").font(.caption.weight(.semibold)).foregroundStyle(Palette.inkSecondary)
                    .gridColumnAlignment(.trailing)
            }
            twilightRow("Civil (−6°)", dawn: .civilDawn, dusk: .civilDusk, times: times)
            twilightRow("Nautique (−12°)", dawn: .nauticalDawn, dusk: .nauticalDusk, times: times)
            twilightRow("Astronomique (−18°)", dawn: .astronomicalDawn, dusk: .astronomicalDusk, times: times)
        }
    }

    private func twilightRow(_ title: String, dawn: SolarEventKind, dusk: SolarEventKind, times: DayTimeFormatter) -> some View {
        GridRow {
            Text(title).foregroundStyle(Palette.ink)
            Text(times.time(day.event(dawn)?.date)).monospacedDigit().foregroundStyle(Palette.ink)
            Text(times.time(day.event(dusk)?.date)).monospacedDigit().foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Crépuscule \(title)")
        .accessibilityValue("aube \(times.time(day.event(dawn)?.date)), crépuscule \(times.time(day.event(dusk)?.date))")
    }
}

/// Legend of the light-phase colours.
struct PhaseLegend: View {
    private let phases: [LightPhase] = [.daylight, .goldenHour, .blueHour, .nauticalTwilight, .astronomicalTwilight, .night]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { items }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), alignment: .leading)], alignment: .leading, spacing: 6) { items }
        }
        .accessibilityHidden(true)
    }

    @ViewBuilder private var items: some View {
        ForEach(phases, id: \.self) { phase in
            HStack(spacing: 4) {
                Rectangle()
                    .fill(Palette.phase(phase))
                    .frame(width: 10, height: 10)
                    .overlay(Rectangle().stroke(Palette.rule, lineWidth: 0.5))
                Text(shortName(phase))
                    .font(.caption2)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }

    private func shortName(_ phase: LightPhase) -> String {
        switch phase {
        case .daylight: return "Jour"
        case .goldenHour: return "Dorée"
        case .blueHour: return "Bleue"
        case .nauticalTwilight: return "Nautique"
        case .astronomicalTwilight: return "Astro."
        case .night: return "Nuit"
        }
    }
}
