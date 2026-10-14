import Foundation

/// Low-level astronomical helpers shared by the solar engine.
///
/// References:
/// - Jean Meeus, *Astronomical Algorithms*, 2nd ed. (Willmann-Bell, 1998), chapters 7, 12, 13, 16 and 25.
/// - F. Espenak & J. Meeus, *Five Millennium Canon of Solar Eclipses* (NASA/TP-2006-214141),
///   polynomial expressions for ΔT.
enum AstroMath {
    static let degreesToRadians = Double.pi / 180
    static let radiansToDegrees = 180 / Double.pi

    /// Julian Day (UT) for an instant. 2440587.5 is the Julian Day of 1970-01-01T00:00:00Z.
    static func julianDay(_ date: Date) -> Double {
        julianDay(unixTime: date.timeIntervalSince1970)
    }

    static func julianDay(unixTime: Double) -> Double {
        unixTime / 86_400 + 2_440_587.5
    }

    /// Approximate decimal year, sufficient for ΔT.
    static func decimalYear(julianDay jd: Double) -> Double {
        2000 + (jd - 2_451_545.0) / 365.25
    }

    /// ΔT = TT − UT in seconds (Espenak & Meeus 2006 polynomials).
    ///
    /// ΔT shifts the solar longitude by ~0.04″ per second, so even a 10 s error
    /// changes the sun position by less than 0.0002°. It is included for correctness,
    /// not because it materially affects photographic times.
    static func deltaT(year y: Double) -> Double {
        switch y {
        case ..<1900:
            let u = (y - 1820) / 100
            return -20 + 32 * u * u
        case ..<1920:
            let t = y - 1900
            return -2.79 + 1.494119 * t - 0.0598939 * t * t + 0.0061966 * pow(t, 3) - 0.000197 * pow(t, 4)
        case ..<1941:
            let t = y - 1920
            return 21.20 + 0.84493 * t - 0.076100 * t * t + 0.0020936 * pow(t, 3)
        case ..<1961:
            let t = y - 1950
            return 29.07 + 0.407 * t - t * t / 233 + pow(t, 3) / 2547
        case ..<1986:
            let t = y - 1975
            return 45.45 + 1.067 * t - t * t / 260 - pow(t, 3) / 718
        case ..<2005:
            let t = y - 2000
            return 63.86 + 0.3345 * t - 0.060374 * t * t + 0.0017275 * pow(t, 3)
                + 0.000651814 * pow(t, 4) + 0.00002373599 * pow(t, 5)
        case ..<2050:
            let t = y - 2000
            return 62.92 + 0.32217 * t + 0.005589 * t * t
        case ..<2150:
            let u = (y - 1820) / 100
            return -20 + 32 * u * u - 0.5628 * (2150 - y)
        default:
            let u = (y - 1820) / 100
            return -20 + 32 * u * u
        }
    }

    /// Normalises an angle to [0, 360).
    static func normalizedDegrees(_ angle: Double) -> Double {
        let r = angle.truncatingRemainder(dividingBy: 360)
        return r < 0 ? r + 360 : r
    }

    /// Normalises an angle to [-180, 180).
    static func signedDegrees(_ angle: Double) -> Double {
        let r = normalizedDegrees(angle)
        return r >= 180 ? r - 360 : r
    }

    static func sinDeg(_ x: Double) -> Double { sin(x * degreesToRadians) }
    static func cosDeg(_ x: Double) -> Double { cos(x * degreesToRadians) }
}
