import Foundation
import SolarEngine

/// Parses coordinates typed by the user.
///
/// Accepted forms (separators: comma, semicolon or whitespace; decimal comma accepted when the
/// pair is separated by a semicolon or whitespace):
/// - `48.8566, 2.3522`
/// - `48.8566 N 2.3522 E`, `N48.8566 E2.3522`
/// - `48°51'24"N 2°21'08"E`, `48° 51.4' N, 2° 21.1' E`
public enum CoordinateParser {
    public static func parse(_ input: String) -> GeoCoordinate? {
        let normalized = input
            .uppercased()
            .replacingOccurrences(of: "′", with: "'")
            .replacingOccurrences(of: "’", with: "'")
            .replacingOccurrences(of: "″", with: "\"")
            .replacingOccurrences(of: "''", with: "\"")
            .replacingOccurrences(of: "º", with: "°")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return nil }

        guard let (first, second) = split(normalized) else { return nil }
        guard let lat = parseComponent(first, positive: "N", negative: "S"),
              let lon = parseComponent(second, positive: "E", negative: "W") ?? parseComponent(second, positive: "E", negative: "O")
        else { return nil }
        return GeoCoordinate(latitude: lat, longitude: lon)
    }

    /// Splits into latitude and longitude parts.
    private static func split(_ s: String) -> (String, String)? {
        // Explicit separators first.
        for separator in [";", ","] where s.contains(separator) {
            let parts = s.components(separatedBy: separator).map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 { return (parts[0], parts[1]) }
            // "48,85 , 2,35" style is ambiguous: only accept exactly two parts.
        }
        // Hemisphere letter after the latitude: "48.85 N 2.35 E" or "48°51'N 2°21'E".
        if let range = s.range(of: #"[NS]"#, options: .regularExpression) {
            let latPart = String(s[..<range.upperBound])
            let lonPart = String(s[range.upperBound...])
            if latPart.rangeOfCharacter(from: .decimalDigits) != nil,
               lonPart.rangeOfCharacter(from: .decimalDigits) != nil {
                return (latPart.trimmingCharacters(in: .whitespaces), lonPart.trimmingCharacters(in: .whitespaces))
            }
            // Hemisphere letter before the value: "N48.85 E2.35".
            let tokens = s.split(separator: " ").map(String.init)
            if tokens.count == 2 { return (tokens[0], tokens[1]) }
        }
        let tokens = s.split(whereSeparator: { $0 == " " }).map(String.init)
        if tokens.count == 2 { return (tokens[0], tokens[1]) }
        return nil
    }

    /// Parses one component in decimal degrees or degrees/minutes/seconds, with an optional hemisphere.
    private static func parseComponent(_ raw: String, positive: Character, negative: Character) -> Double? {
        var s = raw.trimmingCharacters(in: .whitespaces)
        var sign = 1.0
        let letters = s.filter { $0.isLetter }
        if !letters.isEmpty {
            guard letters.count == 1, let letter = letters.first, letter == positive || letter == negative else { return nil }
            if letter == negative { sign = -1 }
            s.removeAll { $0.isLetter }
        }
        s = s.replacingOccurrences(of: ",", with: ".")
        let numbers = s
            .components(separatedBy: CharacterSet(charactersIn: "0123456789.-+").inverted)
            .filter { !$0.isEmpty }
        guard (1...3).contains(numbers.count) else { return nil }
        let values = numbers.compactMap(Double.init)
        guard values.count == numbers.count else { return nil }
        if values.count > 1 {
            // Minutes and seconds must be positive and below 60; a sign belongs to the degrees only.
            guard values.dropFirst().allSatisfy({ $0 >= 0 && $0 < 60 }) else { return nil }
        }
        let degrees = values[0]
        var magnitude = abs(degrees)
        if values.count > 1 { magnitude += values[1] / 60 }
        if values.count > 2 { magnitude += values[2] / 3600 }
        if degrees.sign == .minus {
            // "-48.85 S" is contradictory.
            guard sign > 0 else { return nil }
            sign = -1
        }
        return sign * magnitude
    }
}
