import Foundation

/// Solar elevation thresholds (degrees, geometric elevation of the Sun's centre) used to define
/// each light phase.
///
/// Sunrise/sunset and the three twilights have official definitions. The golden hour and the blue hour
/// do **not**: different photographers, apps and publications use different values. GoldenHour uses the
/// widely used photographic convention below and exposes it so the choice is explicit and testable:
///
/// | Phase             | Sun elevation               |
/// |-------------------|-----------------------------|
/// | Daylight          | ≥ +6°                       |
/// | Golden hour       | −4° … +6°                   |
/// | Blue hour         | −6° … −4°                   |
/// | Nautical twilight | −12° … −6°                  |
/// | Astronomical tw.  | −18° … −12°                 |
/// | Night             | < −18°                      |
///
/// Sunrise and sunset occur at −0.833° (34′ of standard refraction + 16′ solar semi-diameter),
/// which is the convention of the US Naval Observatory and of most almanacs.
public struct LightConventions: Hashable, Sendable, Codable {
    /// Upper bound of the golden hour (start of "daylight").
    public var goldenHourUpper: Double
    /// Lower bound of the golden hour, which is also the upper bound of the blue hour.
    public var goldenHourLower: Double
    /// Lower bound of the blue hour.
    public var blueHourLower: Double

    public init(goldenHourUpper: Double = 6, goldenHourLower: Double = -4, blueHourLower: Double = -6) {
        precondition(goldenHourUpper > goldenHourLower && goldenHourLower > blueHourLower,
                     "Thresholds must be strictly decreasing")
        precondition(blueHourLower > SolarThreshold.nauticalTwilight,
                     "The blue hour must stay above the nautical twilight threshold")
        self.goldenHourUpper = goldenHourUpper
        self.goldenHourLower = goldenHourLower
        self.blueHourLower = blueHourLower
    }

    public static let standard = LightConventions()

    /// Light phase for a geometric solar elevation.
    public func phase(forElevation elevation: Double) -> LightPhase {
        switch elevation {
        case goldenHourUpper...: return .daylight
        case goldenHourLower...: return .goldenHour
        case blueHourLower...: return .blueHour
        case SolarThreshold.nauticalTwilight...: return .nauticalTwilight
        case SolarThreshold.astronomicalTwilight...: return .astronomicalTwilight
        default: return .night
        }
    }

    /// All elevations at which the light phase or a named event changes.
    var allThresholds: [Double] {
        Array(Set([
            SolarThreshold.astronomicalTwilight,
            SolarThreshold.nauticalTwilight,
            SolarThreshold.civilTwilight,
            SolarThreshold.horizon,
            blueHourLower,
            goldenHourLower,
            goldenHourUpper,
        ])).sorted()
    }

    /// Thresholds that delimit `LightPhase` values.
    var phaseThresholds: [Double] {
        [SolarThreshold.astronomicalTwilight, SolarThreshold.nauticalTwilight,
         blueHourLower, goldenHourLower, goldenHourUpper]
    }
}

/// Standard solar elevation thresholds in degrees.
public enum SolarThreshold {
    /// Sunrise / sunset: upper limb on the horizon with standard refraction.
    public static let horizon = -0.8333
    public static let civilTwilight = -6.0
    public static let nauticalTwilight = -12.0
    public static let astronomicalTwilight = -18.0
}

/// Photographic light phase, ordered from darkest to brightest.
public enum LightPhase: Int, CaseIterable, Comparable, Sendable, Codable {
    case night
    case astronomicalTwilight
    case nauticalTwilight
    case blueHour
    case goldenHour
    case daylight

    public static func < (lhs: LightPhase, rhs: LightPhase) -> Bool { lhs.rawValue < rhs.rawValue }
}
