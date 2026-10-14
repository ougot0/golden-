import Foundation

/// Reliability of a magnetometer-derived heading.
///
/// `CLHeading.headingAccuracy` is the maximum deviation in degrees between the reported heading and
/// true north; a negative value means the heading is invalid. GoldenHour never presents a heading as a
/// reliable measurement unless the accuracy is known and good.
public enum HeadingReliability: Equatable, Sendable {
    /// No heading (no magnetometer, permission refused, or invalid reading).
    case unavailable
    /// Accuracy worse than `approximateLimit`: the device needs calibration; directions must not be shown as measurements.
    case needsCalibration(accuracy: Double)
    /// Usable but approximate.
    case approximate(accuracy: Double)
    /// Accuracy within `goodLimit`.
    case good(accuracy: Double)

    public static let goodLimit = 10.0
    public static let approximateLimit = 25.0

    public init(headingAccuracy: Double?) {
        guard let accuracy = headingAccuracy, accuracy >= 0, accuracy.isFinite else {
            self = .unavailable
            return
        }
        switch accuracy {
        case ...Self.goodLimit: self = .good(accuracy: accuracy)
        case ...Self.approximateLimit: self = .approximate(accuracy: accuracy)
        default: self = .needsCalibration(accuracy: accuracy)
        }
    }

    /// Whether the dial may be rotated to follow the device.
    public var allowsLiveOrientation: Bool {
        switch self {
        case .good, .approximate: return true
        case .unavailable, .needsCalibration: return false
        }
    }
}

public enum CompassMath {
    /// Normalises an angle to [0, 360).
    public static func normalized(_ degrees: Double) -> Double {
        let r = degrees.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Signed smallest rotation from `from` to `to`, in (-180, 180].
    public static func signedDelta(from: Double, to: Double) -> Double {
        var d = normalized(to - from)
        if d > 180 { d -= 360 }
        return d
    }

    /// Bearing of a target relative to where the device points: 0 = straight ahead, positive = to the right.
    public static func relativeBearing(target: Double, heading: Double) -> Double {
        signedDelta(from: heading, to: target)
    }

    /// Unwraps a new heading so animations never spin the long way around (359° → 1°).
    public static func continuousAngle(previous: Double, next: Double) -> Double {
        previous + signedDelta(from: previous, to: next)
    }

    /// 16-point compass abbreviation in French (N, NNE, NE, …, O for ouest).
    public static func cardinalAbbreviation(for azimuth: Double) -> String {
        let names = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                     "S", "SSO", "SO", "OSO", "O", "ONO", "NO", "NNO"]
        let index = Int((normalized(azimuth) / 22.5).rounded()) % 16
        return names[index]
    }
}
