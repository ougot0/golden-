import Foundation

/// Position of the Sun as seen by an observer at a given instant.
public struct SolarPosition: Sendable, Equatable {
    /// Azimuth in degrees, measured clockwise from true (geographic) north: 0 = N, 90 = E, 180 = S, 270 = W.
    public let azimuth: Double
    /// Topocentric elevation of the Sun's centre in degrees, **without** atmospheric refraction.
    /// All light-phase thresholds in this engine are expressed on this quantity.
    public let elevation: Double
    /// Declination in degrees.
    public let declination: Double
    /// Local hour angle in degrees, in [-180, 180). Negative before the meridian transit (morning).
    public let hourAngle: Double

    /// Elevation including standard atmospheric refraction (10 °C, 1010 hPa).
    /// This is what an observer actually sees; it differs from `elevation` by ~0.5° at the horizon.
    public var apparentElevation: Double {
        elevation + Refraction.standardCorrection(forGeometricElevation: elevation)
    }
}

/// Solar position algorithm.
///
/// Implements the "low accuracy" solar coordinates of Meeus, *Astronomical Algorithms*, ch. 25
/// (apparent longitude corrected for nutation and aberration), Greenwich mean sidereal time
/// from ch. 12, the horizontal transformation from ch. 13 and the horizontal parallax of the Sun.
/// Documented accuracy of the solar coordinates is about 0.01°, which corresponds to a few seconds
/// of time for sunrise/sunset at mid-latitudes.
public enum SolarCalculator {
    /// Equatorial horizontal parallax of the Sun (8.794″) in degrees.
    private static let solarParallax = 8.794 / 3600

    public static func position(at date: Date, coordinate: GeoCoordinate) -> SolarPosition {
        position(unixTime: date.timeIntervalSince1970, latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    static func position(unixTime: Double, latitude: Double, longitude: Double) -> SolarPosition {
        let jdUT = AstroMath.julianDay(unixTime: unixTime)
        let deltaT = AstroMath.deltaT(year: AstroMath.decimalYear(julianDay: jdUT))
        let jdTT = jdUT + deltaT / 86_400
        let t = (jdTT - 2_451_545.0) / 36_525 // Julian centuries (TT) since J2000.0

        // Geometric mean longitude and mean anomaly (Meeus 25.2, 25.3).
        let l0 = AstroMath.normalizedDegrees(280.46646 + 36_000.76983 * t + 0.0003032 * t * t)
        let m = AstroMath.normalizedDegrees(357.52911 + 35_999.05029 * t - 0.0001537 * t * t)

        // Equation of centre.
        let c = (1.914602 - 0.004817 * t - 0.000014 * t * t) * AstroMath.sinDeg(m)
            + (0.019993 - 0.000101 * t) * AstroMath.sinDeg(2 * m)
            + 0.000289 * AstroMath.sinDeg(3 * m)
        let trueLongitude = l0 + c

        // Apparent longitude: nutation in longitude and aberration (Meeus 25 "λ").
        let omega = 125.04 - 1934.136 * t
        let lambda = trueLongitude - 0.00569 - 0.00478 * AstroMath.sinDeg(omega)

        // Obliquity of the ecliptic (Meeus 22.2) corrected for nutation (25.8).
        let seconds = 21.448 - 46.8150 * t - 0.00059 * t * t + 0.001813 * t * t * t
        let epsilon0 = 23 + (26 + seconds / 60) / 60
        let epsilon = epsilon0 + 0.00256 * AstroMath.cosDeg(omega)

        let sinLambda = AstroMath.sinDeg(lambda)
        let rightAscension = AstroMath.normalizedDegrees(
            atan2(AstroMath.cosDeg(epsilon) * sinLambda, AstroMath.cosDeg(lambda)) * AstroMath.radiansToDegrees
        )
        let declination = asin(AstroMath.sinDeg(epsilon) * sinLambda) * AstroMath.radiansToDegrees

        // Greenwich mean sidereal time (Meeus 12.4), using UT.
        let d = jdUT - 2_451_545.0
        let tu = d / 36_525
        let gmst = AstroMath.normalizedDegrees(
            280.46061837 + 360.98564736629 * d + 0.000387933 * tu * tu - tu * tu * tu / 38_710_000
        )
        // Equation of the equinoxes (nutation in right ascension), ~1 s of time.
        let deltaPsi = -0.004778 * AstroMath.sinDeg(omega)
        let gast = gmst + deltaPsi * AstroMath.cosDeg(epsilon)

        let hourAngle = AstroMath.signedDegrees(gast + longitude - rightAscension)

        let phi = latitude * AstroMath.degreesToRadians
        let delta = declination * AstroMath.degreesToRadians
        let h = hourAngle * AstroMath.degreesToRadians

        let sinElevation = sin(phi) * sin(delta) + cos(phi) * cos(delta) * cos(h)
        let geocentricElevation = asin(max(-1, min(1, sinElevation))) * AstroMath.radiansToDegrees
        // Parallax in altitude (≤ 0.0024°).
        let elevation = geocentricElevation - solarParallax * AstroMath.cosDeg(geocentricElevation)

        let azimuthRad = atan2(
            -cos(delta) * sin(h),
            sin(delta) * cos(phi) - cos(delta) * cos(h) * sin(phi)
        )
        let azimuth = AstroMath.normalizedDegrees(azimuthRad * AstroMath.radiansToDegrees)

        return SolarPosition(azimuth: azimuth, elevation: elevation, declination: declination, hourAngle: hourAngle)
    }
}

/// Atmospheric refraction model.
public enum Refraction {
    /// Refraction in degrees to add to a geometric elevation, for standard conditions.
    ///
    /// Sæmundsson's formula (Meeus 16.4), which inverts Bennett's formula and is accurate to ~0.1′
    /// above the horizon. Below −1° (sun well under the horizon) refraction is irrelevant and 0 is returned;
    /// between −1° and 0° the value is held continuous by evaluating at the clamped elevation.
    public static func standardCorrection(forGeometricElevation h: Double) -> Double {
        guard h > -1 else { return 0 }
        let clamped = max(h, -0.9)
        let arcMinutes = 1.02 / tan((clamped + 10.3 / (clamped + 5.11)) * AstroMath.degreesToRadians)
        return max(0, arcMinutes / 60)
    }
}
