import SwiftUI
import UIKit
import SolarEngine

/// Colour tokens.
///
/// Derived from the brief (charcoal #151717, warm white #F3F0E9, solar amber #D99A45, slate #727775)
/// with two adjustments made for legibility:
/// - Slate #727775 is below the WCAG AA contrast ratio for small text on both backgrounds, so secondary
///   text uses a darker slate in light mode and a lighter one in dark mode.
/// - Amber #D99A45 is used for graphics and fills. Amber *text* uses a deeper tone on warm white and a
///   lighter tone on charcoal so it stays readable in direct sunlight.
enum Palette {
    static let background = dynamic(light: 0xF3F0E9, dark: 0x151717)
    static let surface = dynamic(light: 0xEAE6DC, dark: 0x1D2020)
    static let ink = dynamic(light: 0x151717, dark: 0xF3F0E9)
    static let inkSecondary = dynamic(light: 0x545957, dark: 0xA3A8A5)
    static let rule = dynamic(light: 0xD3CEC2, dark: 0x2E3232)
    static let amber = Color(hex: 0xD99A45)
    static let amberText = dynamic(light: 0x8A5514, dark: 0xE5AC60)
    static let warning = dynamic(light: 0x9A3B1E, dark: 0xF08A62)

    /// Colours of the light phases. They describe the light itself, so they are the same in both themes;
    /// each one is distinguishable from its neighbours for the common forms of colour blindness because
    /// luminance increases monotonically from night to daylight.
    static func phase(_ phase: LightPhase) -> Color {
        switch phase {
        case .night: return Color(hex: 0x10141C)
        case .astronomicalTwilight: return Color(hex: 0x1C2638)
        case .nauticalTwilight: return Color(hex: 0x2C3F5E)
        case .blueHour: return Color(hex: 0x4A6E9E)
        case .goldenHour: return Color(hex: 0xD99A45)
        case .daylight: return Color(hex: 0xE9DDBF)
        }
    }

    private static func dynamic(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(uiColor: UIColor(hex: hex))
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
