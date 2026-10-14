import SwiftUI
import SolarEngine

/// Polar sky chart: the centre is the zenith, the rim is the horizon, azimuth clockwise from north.
///
/// `rotation` (degrees) rotates the whole dial so that it matches the real world when the device heading
/// is reliable; it is 0 (north up) otherwise.
struct CompassDial: View {
    let rotation: Double
    let path: [SolarPath.Sample]
    let sunrise: Double?
    let sunset: Double?
    let sun: SolarPosition?
    let showsDeviceIndicator: Bool

    var body: some View {
        ZStack {
            Canvas { context, size in
                let radius = min(size.width, size.height) / 2 - 22
                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                drawDial(in: &context, center: center, radius: radius)
            }
            .rotationEffect(.degrees(rotation))

            if showsDeviceIndicator {
                VStack {
                    Image(systemName: "arrowtriangle.down.fill")
                        .font(.caption)
                        .foregroundStyle(Palette.amber)
                    Spacer()
                }
                .accessibilityHidden(true)
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Cadran solaire")
        .accessibilityValue(accessibilityDescription)
    }

    private func point(azimuth: Double, elevation: Double, center: CGPoint, radius: CGFloat) -> CGPoint {
        let r = radius * CGFloat((90 - max(0, elevation)) / 90)
        let angle = (azimuth - 90) * .pi / 180
        return CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
    }

    private func drawDial(in context: inout GraphicsContext, center: CGPoint, radius: CGFloat) {
        // Elevation rings at 0°, 30°, 60°.
        for elevation in [0.0, 30.0, 60.0] {
            let r = radius * CGFloat((90 - elevation) / 90)
            let rect = CGRect(x: center.x - r, y: center.y - r, width: 2 * r, height: 2 * r)
            context.stroke(Path(ellipseIn: rect), with: .color(elevation == 0 ? Palette.ink : Palette.rule),
                           lineWidth: elevation == 0 ? 1.5 : 1)
        }

        // Ticks every 5°, longer every 30°.
        for degree in stride(from: 0, to: 360, by: 5) {
            let angle = (Double(degree) - 90) * .pi / 180
            let long = degree % 30 == 0
            let inner = radius + 2
            let outer = radius + (long ? 10 : 5)
            var tick = Path()
            tick.move(to: CGPoint(x: center.x + inner * CGFloat(cos(angle)), y: center.y + inner * CGFloat(sin(angle))))
            tick.addLine(to: CGPoint(x: center.x + outer * CGFloat(cos(angle)), y: center.y + outer * CGFloat(sin(angle))))
            context.stroke(tick, with: .color(long ? Palette.ink : Palette.inkSecondary), lineWidth: long ? 1.5 : 0.75)
        }

        // Cardinal letters.
        for (label, degree) in [("N", 0.0), ("E", 90.0), ("S", 180.0), ("O", 270.0)] {
            let angle = (degree - 90) * .pi / 180
            let r = radius - 12
            let position = CGPoint(x: center.x + r * CGFloat(cos(angle)), y: center.y + r * CGFloat(sin(angle)))
            let text = Text(label)
                .font(.caption.weight(.bold))
                .foregroundColor(label == "N" ? Palette.warning : Palette.inkSecondary)
            context.draw(text, at: position)
        }

        // Sunrise / sunset directions.
        for (azimuth, isRise) in [(sunrise, true), (sunset, false)] {
            guard let azimuth else { continue }
            var line = Path()
            line.move(to: center)
            line.addLine(to: point(azimuth: azimuth, elevation: 0, center: center, radius: radius))
            context.stroke(line, with: .color(Palette.amber.opacity(isRise ? 0.9 : 0.6)),
                           style: StrokeStyle(lineWidth: 1.5, dash: isRise ? [] : [4, 3]))
        }

        // Sun path above the horizon, split into continuous arcs.
        var arc = Path()
        var drawing = false
        for sample in path {
            if sample.elevation >= 0 {
                let p = point(azimuth: sample.azimuth, elevation: sample.elevation, center: center, radius: radius)
                if drawing { arc.addLine(to: p) } else { arc.move(to: p); drawing = true }
            } else {
                drawing = false
            }
        }
        context.stroke(arc, with: .color(Palette.ink), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

        // Current sun.
        if let sun {
            if sun.elevation >= 0 {
                let p = point(azimuth: sun.azimuth, elevation: sun.elevation, center: center, radius: radius)
                context.fill(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(Palette.amber))
                context.stroke(Path(ellipseIn: CGRect(x: p.x - 9, y: p.y - 9, width: 18, height: 18)), with: .color(Palette.ink), lineWidth: 1)
            } else {
                // Below the horizon: hollow marker on the rim, in the sun's direction.
                let p = point(azimuth: sun.azimuth, elevation: 0, center: center, radius: radius)
                context.stroke(Path(ellipseIn: CGRect(x: p.x - 7, y: p.y - 7, width: 14, height: 14)), with: .color(Palette.amber), lineWidth: 2)
            }
        }
    }

    private var accessibilityDescription: String {
        var parts: [String] = []
        if let sun {
            parts.append("Soleil à l'azimut \(Int(sun.azimuth.rounded())) degrés, élévation \(Int(sun.elevation.rounded())) degrés")
        }
        if let sunrise { parts.append("lever à \(Int(sunrise.rounded())) degrés") }
        if let sunset { parts.append("coucher à \(Int(sunset.rounded())) degrés") }
        parts.append(showsDeviceIndicator ? "cadran orienté selon l'appareil" : "cadran affiché nord en haut")
        return parts.joined(separator: ", ")
    }
}
