import SwiftUI
import SolarEngine
import GoldenHourCore

/// Hour-by-hour forecast for each golden and blue hour of the day shown.
struct WeatherSection: View {
    let day: SolarDay
    @Environment(AppSettings.self) private var settings
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var provider = WeatherProvider()

    private var periods: [LightPeriod] {
        (day.goldenHours + day.blueHours)
            .filter { WeatherForecast.isForecastable($0.interval, now: .now) }
            .sorted { $0.start < $1.start }
    }

    var body: some View {
        if !periods.isEmpty {
            InstrumentSection(title: "Météo des heures dorées et bleues") {
                content
                attribution
            }
            .task(id: TaskKey(date: day.date, coordinate: day.coordinate)) {
                await provider.load(interval: WeatherForecast.requestInterval(for: day), coordinate: day.coordinate)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                Task { await provider.load(interval: WeatherForecast.requestInterval(for: day), coordinate: day.coordinate) }
            }
        }
    }

    private struct TaskKey: Equatable {
        let date: LocalDate
        let coordinate: GeoCoordinate
    }

    @ViewBuilder
    private var content: some View {
        switch provider.state {
        case .idle, .loading:
            HStack(spacing: 8) {
                ProgressView()
                Text("Chargement des prévisions…").font(.subheadline).foregroundStyle(Palette.inkSecondary)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(.subheadline).foregroundStyle(Palette.inkSecondary)
                Button("Réessayer") {
                    Task {
                        await provider.load(interval: WeatherForecast.requestInterval(for: day),
                                            coordinate: day.coordinate, force: true)
                    }
                }
                .font(.subheadline.weight(.semibold))
            }
        case .loaded(let samples, let fetchedAt):
            let formatter = SolarTimeFormatter(timeZone: day.timeZone, hourCycle: settings.hourCycle)
            VStack(alignment: .leading, spacing: 18) {
                ForEach(periods, id: \.self) { period in
                    PeriodForecast(
                        period: period,
                        samples: WeatherForecast.samples(overlapping: period.interval, in: samples),
                        formatter: formatter
                    )
                }
                Text("Prévisions mises à jour à \(formatter.time(fetchedAt)). Nébulosité : part du ciel couverte par les nuages.")
                    .font(.caption)
                    .foregroundStyle(Palette.inkSecondary)
            }
        }
    }

    /// Apple requires its mark and a link to the data sources wherever WeatherKit data is shown.
    @ViewBuilder
    private var attribution: some View {
        if let attribution = provider.attribution {
            HStack(spacing: 10) {
                AsyncImage(url: colorScheme == .dark ? attribution.darkMarkURL : attribution.lightMarkURL) { image in
                    image.resizable().scaledToFit()
                } placeholder: {
                    Text(" Météo").font(.caption.weight(.semibold))
                }
                .frame(height: 12)
                .accessibilityLabel("Données Apple Météo")
                Link("Sources des données", destination: attribution.legalPageURL)
                    .font(.caption)
            }
        }
    }
}

private struct PeriodForecast: View {
    let period: LightPeriod
    let samples: [WeatherSample]
    let formatter: SolarTimeFormatter

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(SolarStrings.period(period))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(period.phase == .goldenHour ? Palette.amberText : Palette.ink)
                Spacer()
                Text("\(formatter.time(period.start)) – \(formatter.time(period.end))")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
            }
            if samples.isEmpty {
                Text("Pas encore de prévision pour ce créneau.")
                    .font(.caption).foregroundStyle(Palette.inkSecondary)
            } else {
                ForEach(samples, id: \.date) { sample in
                    HourRow(sample: sample, formatter: formatter)
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

private struct HourRow: View {
    let sample: WeatherSample
    let formatter: SolarTimeFormatter

    var body: some View {
        HStack(spacing: 12) {
            Text(formatter.time(sample.date))
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(Palette.inkSecondary)
                .frame(minWidth: 48, alignment: .leading)
            Image(systemName: sample.symbolName)
                .symbolRenderingMode(.multicolor)
                .frame(width: 24)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(sample.conditionDescription).font(.subheadline).foregroundStyle(Palette.ink)
                Text("Nuages \(percent(sample.cloudCover)) · Pluie \(percent(sample.precipitationChance))")
                    .font(.caption).monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
            }
            Spacer(minLength: 8)
            Text("\(Int(sample.temperatureCelsius.rounded()))°")
                .font(.subheadline).monospacedDigit()
                .foregroundStyle(Palette.ink)
        }
        .accessibilityElement(children: .combine)
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded())) %"
    }
}
