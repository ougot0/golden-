import SwiftUI
import SolarEngine
import GoldenHourCore

/// Elevation curve of the Sun over the local day, above a band showing the light phases.
///
/// The x axis is the local day (23, 24 or 25 hours on DST days). Hour ticks are placed at real local
/// hours, so on a DST day the spacing is still correct.
struct DayTimelineView: View {
    let day: SolarDay
    let samples: [SolarPath.Sample]
    /// Current instant, drawn as a marker when it falls inside the day.
    var now: Date?
    var hourCycle: HourCycle = .system

    private let bandHeight: CGFloat = 14
    private let chartHeight: CGFloat = 120
    private let minElevation = -20.0

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Canvas { context, size in
                draw(in: &context, size: size)
            }
            .frame(height: chartHeight + bandHeight + 6)
            hourLabels
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Frise de la journée")
        .accessibilityValue(accessibilitySummary)
    }

    private var maxElevation: Double {
        max(10, (samples.map(\.elevation).max() ?? 10) + 5)
    }

    private func x(for date: Date, width: CGFloat) -> CGFloat {
        let fraction = date.timeIntervalSince(day.interval.start) / day.interval.duration
        return CGFloat(min(max(fraction, 0), 1)) * width
    }

    private func y(for elevation: Double) -> CGFloat {
        let clamped = min(max(elevation, minElevation), maxElevation)
        let fraction = (clamped - minElevation) / (maxElevation - minElevation)
        return chartHeight * CGFloat(1 - fraction)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let width = size.width

        // Light-phase band.
        let bandTop = chartHeight + 6
        for segment in day.timeline {
            let x0 = x(for: segment.interval.start, width: width)
            let x1 = x(for: segment.interval.end, width: width)
            context.fill(Path(CGRect(x: x0, y: bandTop, width: max(0.5, x1 - x0), height: bandHeight)),
                         with: .color(Palette.phase(segment.phase)))
        }

        // Reference lines: horizon, −6° and +6°.
        for (elevation, dashed) in [(0.0, false), (-6.0, true), (6.0, true)] {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: y(for: elevation)))
            line.addLine(to: CGPoint(x: width, y: y(for: elevation)))
            context.stroke(line, with: .color(Palette.rule),
                           style: StrokeStyle(lineWidth: 1, dash: dashed ? [3, 3] : []))
        }

        // Hour ticks.
        for tick in hourTicks {
            var path = Path()
            let px = x(for: tick, width: width)
            path.move(to: CGPoint(x: px, y: chartHeight - 4))
            path.addLine(to: CGPoint(x: px, y: chartHeight + 2))
            context.stroke(path, with: .color(Palette.rule), lineWidth: 1)
        }

        // Elevation curve.
        guard let first = samples.first else { return }
        var curve = Path()
        curve.move(to: CGPoint(x: x(for: first.date, width: width), y: y(for: first.elevation)))
        for sample in samples.dropFirst() {
            curve.addLine(to: CGPoint(x: x(for: sample.date, width: width), y: y(for: sample.elevation)))
        }
        context.stroke(curve, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

        // Current time.
        if let now, day.interval.contains(now) {
            let px = x(for: now, width: width)
            var marker = Path()
            marker.move(to: CGPoint(x: px, y: 0))
            marker.addLine(to: CGPoint(x: px, y: bandTop + bandHeight))
            context.stroke(marker, with: .color(Palette.amber), lineWidth: 2)
            let elevation = SolarCalculator.position(at: now, coordinate: day.coordinate).elevation
            let dot = CGRect(x: px - 4, y: y(for: elevation) - 4, width: 8, height: 8)
            context.fill(Path(ellipseIn: dot), with: .color(Palette.amber))
        }
    }

    /// Local hours 0, 6, 12, 18 of the day.
    private var hourTicks: [Date] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = day.timeZone
        return [6, 12, 18].compactMap { hour in
            calendar.date(bySettingHour: hour, minute: 0, second: 0, of: day.interval.start)
        }
    }

    private var hourLabels: some View {
        GeometryReader { proxy in
            let formatter = SolarTimeFormatter(timeZone: day.timeZone, hourCycle: hourCycle)
            ForEach(hourTicks, id: \.self) { tick in
                Text(formatter.time(tick))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(Palette.inkSecondary)
                    .fixedSize()
                    .position(x: x(for: tick, width: proxy.size.width), y: 8)
            }
        }
        .frame(height: 16)
    }

    private var accessibilitySummary: String {
        let formatter = SolarTimeFormatter(timeZone: day.timeZone, hourCycle: hourCycle)
        return day.timeline.map { segment in
            "\(SolarStrings.phase(segment.phase)) de \(formatter.time(segment.interval.start)) à \(formatter.time(segment.interval.end))"
        }.joined(separator: ", ")
    }
}
