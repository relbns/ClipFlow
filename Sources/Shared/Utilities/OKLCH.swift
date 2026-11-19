import SwiftUI

/// A color in OKLCH, the space the design prototype is written in, converted to sRGB the way a browser does.
struct OKLCH: Equatable {
    let lightness: Double
    let chroma: Double
    let hue: Double
    var alpha: Double = 1

    init(_ lightness: Double, _ chroma: Double, _ hue: Double, alpha: Double = 1) {
        self.lightness = lightness
        self.chroma = chroma
        self.hue = hue
        self.alpha = alpha
    }

    /// Gamma-encoded sRGB components in 0...1, clipped to the sRGB gamut.
    var sRGB: (red: Double, green: Double, blue: Double) {
        let hueRadians = hue * .pi / 180
        let a = chroma * cos(hueRadians)
        let b = chroma * sin(hueRadians)

        let l = pow(lightness + 0.3963377774 * a + 0.2158037573 * b, 3)
        let m = pow(lightness - 0.1055613458 * a - 0.0638541728 * b, 3)
        let s = pow(lightness - 0.0894841775 * a - 1.2914855480 * b, 3)

        let linearRed = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let linearGreen = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let linearBlue = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s

        return (Self.encode(linearRed), Self.encode(linearGreen), Self.encode(linearBlue))
    }

    /// `#RRGGBB`, for tests and debugging.
    var hex: String {
        let (red, green, blue) = sRGB
        return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    var color: Color {
        let (red, green, blue) = sRGB
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: alpha)
    }

    private static func encode(_ linear: Double) -> Double {
        let clipped = min(1, max(0, linear))
        return clipped <= 0.0031308 ? 12.92 * clipped : 1.055 * pow(clipped, 1 / 2.4) - 0.055
    }
}

extension Color {
    static func oklch(_ lightness: Double, _ chroma: Double, _ hue: Double, alpha: Double = 1) -> Color {
        OKLCH(lightness, chroma, hue, alpha: alpha).color
    }

    /// The design's `color-mix(in oklab, <color> N%, transparent)`.
    func mixed(_ percent: Double) -> Color {
        opacity(percent / 100)
    }

    /// `#RRGGBB` or `#RRGGBBAA` from the design's CSS.
    static func hex(_ value: UInt32, alpha: Double = 1) -> Color {
        Color(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255,
            opacity: alpha
        )
    }
}
