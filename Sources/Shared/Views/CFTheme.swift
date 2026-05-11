import SwiftUI

/// ClipFlow design tokens matching the design system
/// Based on CSS variables from the design file
struct CFTheme {
    // MARK: - Color Scheme
    let colorScheme: ColorScheme

    // MARK: - Text Colors
    let textStrong: Color
    let text: Color
    let textMid: Color
    let textMuted: Color
    let textSubtle: Color
    let textLabel: Color
    let textFaint: Color
    let textBullet: Color

    // MARK: - Fill Colors
    let fillSoft: Color
    let fill1: Color
    let fill2: Color
    let fill3: Color

    // MARK: - Stroke Colors
    let stroke: Color
    let strokeSoft: Color

    // MARK: - Surface Colors
    let surface: Color
    let surfaceAlt: Color
    let surfaceDeep: Color
    let inputBg: Color

    // MARK: - Gradient Backgrounds
    let popoverBg: LinearGradient
    let titlebarBg: LinearGradient
    let statusbarBg: LinearGradient
    let btnBg: LinearGradient
    let segSelected: LinearGradient

    // MARK: - Shadows
    let shadowSoft: Color
    let shadowStrong: Color
    let shadowDeep: Color

    // MARK: - Special
    let insetHi: Color
    let knob: Color

    // MARK: - Accent
    let accent: Color  // oklch(.6 .17 272) → warm indigo

    // MARK: - Computed Colors
    var popoverBgSolid: Color {
        colorScheme == .dark
            ? Color(red: 46/255, green: 46/255, blue: 52/255).opacity(0.92)
            : Color(red: 252/255, green: 252/255, blue: 254/255).opacity(0.92)
    }

    // MARK: - Theme Factory
    static let light = CFTheme(
        colorScheme: .light,

        // Text
        textStrong: Color(red: 10/255, green: 10/255, blue: 12/255),
        text: Color.black.opacity(0.86),
        textMid: Color.black.opacity(0.66),
        textMuted: Color.black.opacity(0.55),
        textSubtle: Color.black.opacity(0.46),
        textLabel: Color.black.opacity(0.42),
        textFaint: Color.black.opacity(0.36),
        textBullet: Color.black.opacity(0.28),

        // Fills
        fillSoft: Color.black.opacity(0.02),
        fill1: Color.black.opacity(0.05),
        fill2: Color.black.opacity(0.07),
        fill3: Color.black.opacity(0.11),

        // Strokes
        stroke: Color.black.opacity(0.10),
        strokeSoft: Color.black.opacity(0.07),

        // Surfaces
        surface: Color(red: 246/255, green: 246/255, blue: 248/255),
        surfaceAlt: Color(red: 236/255, green: 236/255, blue: 239/255),
        surfaceDeep: Color(red: 255/255, green: 255/255, blue: 255/255),
        inputBg: Color(red: 255/255, green: 255/255, blue: 255/255),

        // Gradients
        popoverBg: LinearGradient(
            colors: [
                Color(red: 252/255, green: 252/255, blue: 254/255).opacity(0.85),
                Color(red: 244/255, green: 244/255, blue: 247/255).opacity(0.85)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        titlebarBg: LinearGradient(
            colors: [
                Color(red: 241/255, green: 241/255, blue: 243/255),
                Color(red: 230/255, green: 230/255, blue: 233/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        statusbarBg: LinearGradient(
            colors: [
                Color(red: 252/255, green: 252/255, blue: 254/255).opacity(0.72),
                Color(red: 244/255, green: 244/255, blue: 247/255).opacity(0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        btnBg: LinearGradient(
            colors: [
                Color(red: 255/255, green: 255/255, blue: 255/255),
                Color(red: 241/255, green: 241/255, blue: 243/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        segSelected: LinearGradient(
            colors: [
                Color(red: 255/255, green: 255/255, blue: 255/255),
                Color(red: 245/255, green: 245/255, blue: 247/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),

        // Shadows
        shadowSoft: Color.black.opacity(0.06),
        shadowStrong: Color.black.opacity(0.10),
        shadowDeep: Color.black.opacity(0.18),

        // Special
        insetHi: Color.white.opacity(0.65),
        knob: .white,

        // Accent - warm indigo (approximation of oklch(.6 .17 272))
        accent: Color(red: 120/255, green: 113/255, blue: 255/255)
    )

    static let dark = CFTheme(
        colorScheme: .dark,

        // Text
        textStrong: .white,
        text: Color.white.opacity(0.92),
        textMid: Color.white.opacity(0.72),
        textMuted: Color.white.opacity(0.58),
        textSubtle: Color.white.opacity(0.46),
        textLabel: Color.white.opacity(0.42),
        textFaint: Color.white.opacity(0.38),
        textBullet: Color.white.opacity(0.30),

        // Fills
        fillSoft: Color.white.opacity(0.04),
        fill1: Color.white.opacity(0.07),
        fill2: Color.white.opacity(0.10),
        fill3: Color.white.opacity(0.16),

        // Strokes
        stroke: Color.white.opacity(0.08),
        strokeSoft: Color.white.opacity(0.06),

        // Surfaces
        surface: Color(red: 29/255, green: 29/255, blue: 34/255),
        surfaceAlt: Color(red: 26/255, green: 26/255, blue: 31/255),
        surfaceDeep: Color(red: 21/255, green: 21/255, blue: 26/255),
        inputBg: Color.black.opacity(0.30),

        // Gradients
        popoverBg: LinearGradient(
            colors: [
                Color(red: 46/255, green: 46/255, blue: 52/255).opacity(0.92),
                Color(red: 34/255, green: 34/255, blue: 40/255).opacity(0.92)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        titlebarBg: LinearGradient(
            colors: [
                Color(red: 44/255, green: 44/255, blue: 51/255),
                Color(red: 35/255, green: 35/255, blue: 40/255)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        statusbarBg: LinearGradient(
            colors: [
                Color(red: 40/255, green: 40/255, blue: 46/255).opacity(0.72),
                Color(red: 28/255, green: 28/255, blue: 32/255).opacity(0.72)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        btnBg: LinearGradient(
            colors: [
                Color.white.opacity(0.10),
                Color.white.opacity(0.04)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),
        segSelected: LinearGradient(
            colors: [
                Color.white.opacity(0.14),
                Color.white.opacity(0.06)
            ],
            startPoint: .top,
            endPoint: .bottom
        ),

        // Shadows
        shadowSoft: Color.black.opacity(0.20),
        shadowStrong: Color.black.opacity(0.28),
        shadowDeep: Color.black.opacity(0.55),

        // Special
        insetHi: Color.white.opacity(0.08),
        knob: .white,

        // Accent - warm indigo (approximation of oklch(.6 .17 272))
        accent: Color(red: 120/255, green: 113/255, blue: 255/255)
    )
}

// MARK: - Environment Key
private struct CFThemeKey: EnvironmentKey {
    static let defaultValue = CFTheme.light
}

extension EnvironmentValues {
    var cfTheme: CFTheme {
        get { self[CFThemeKey.self] }
        set { self[CFThemeKey.self] = newValue }
    }
}

// MARK: - View Extension
extension View {
    func cfTheme(_ theme: CFTheme) -> some View {
        environment(\.cfTheme, theme)
    }

    /// Automatically apply theme based on ColorScheme
    func cfAutoTheme() -> some View {
        modifier(AutoThemeModifier())
    }
}

private struct AutoThemeModifier: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .environment(\.cfTheme, colorScheme == .dark ? .dark : .light)
    }
}

// MARK: - Accent Color Helpers
extension CFTheme {
    /// Returns accent color with specified opacity mixed with transparency
    /// Mimics: color-mix(in oklab, accent X%, transparent)
    func accentMix(percent: Double) -> Color {
        accent.opacity(percent / 100.0)
    }

    /// Category colors for Organized mode groups
    static let categoryColors: [String: Color] = [
        "recent": Color(red: 0.78, green: 0.14, blue: 0.70, opacity: 1.0),   // oklch(.78 .14 70) - amber
        "images": Color(red: 0.74, green: 0.14, blue: 0.60, opacity: 1.0),   // oklch(.74 .14 200) - blue
        "links": Color(red: 0.78, green: 0.14, blue: 0.50, opacity: 1.0),    // oklch(.78 .14 145) - green
        "colors": Color(red: 0.78, green: 0.12, blue: 0.40, opacity: 1.0),   // oklch(.78 .12 320) - magenta
        "text": Color(red: 0.78, green: 0.12, blue: 0.30, opacity: 1.0)      // oklch(.78 .12 30) - orange
    ]

    func categoryColor(for name: String) -> Color {
        CFTheme.categoryColors[name.lowercased()] ?? accent
    }
}

// MARK: - Shadow Styles
extension CFTheme {
    var popoverShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            colorScheme == .dark ? .black.opacity(0.55) : .black.opacity(0.22),
            24,
            0,
            24
        )
    }

    var windowShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            colorScheme == .dark ? .black.opacity(0.5) : .black.opacity(0.22),
            30,
            0,
            30
        )
    }

    var btnShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            colorScheme == .dark ? .black.opacity(0.2) : .black.opacity(0.06),
            1,
            0,
            1
        )
    }

    var segShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            colorScheme == .dark ? .black.opacity(0.25) : .black.opacity(0.10),
            1.5,
            0,
            1
        )
    }

    var knobShadow: (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
        (
            colorScheme == .dark ? .black.opacity(0.4) : .black.opacity(0.18),
            2,
            0,
            1
        )
    }
}

// MARK: - Preview
#if DEBUG
struct CFTheme_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ThemeShowcase()
                .cfTheme(.light)
                .previewDisplayName("Light Theme")

            ThemeShowcase()
                .cfTheme(.dark)
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Theme")
        }
    }

    struct ThemeShowcase: View {
        @Environment(\.cfTheme) var theme

        var body: some View {
            VStack(spacing: 20) {
                Text("ClipFlow Theme System")
                    .font(.title)
                    .foregroundColor(theme.textStrong)

                HStack(spacing: 10) {
                    ColorSwatch(color: theme.accent, label: "Accent")
                    ColorSwatch(color: theme.textStrong, label: "Text Strong")
                    ColorSwatch(color: theme.text, label: "Text")
                    ColorSwatch(color: theme.surface, label: "Surface")
                    ColorSwatch(color: theme.surfaceAlt, label: "Surface Alt")
                }

                HStack(spacing: 10) {
                    ColorSwatch(color: theme.fill1, label: "Fill 1")
                    ColorSwatch(color: theme.fill2, label: "Fill 2")
                    ColorSwatch(color: theme.fill3, label: "Fill 3")
                    ColorSwatch(color: theme.stroke, label: "Stroke")
                }

                Rectangle()
                    .fill(theme.popoverBg)
                    .frame(height: 60)
                    .overlay(
                        Text("Popover Gradient")
                            .foregroundColor(theme.text)
                    )

                Rectangle()
                    .fill(theme.btnBg)
                    .frame(height: 40)
                    .cornerRadius(6)
                    .shadow(color: theme.btnShadow.color, radius: theme.btnShadow.radius, x: theme.btnShadow.x, y: theme.btnShadow.y)
                    .overlay(
                        Text("Button")
                            .foregroundColor(theme.textStrong)
                    )
            }
            .padding(30)
            .background(theme.surfaceDeep)
        }

        struct ColorSwatch: View {
            let color: Color
            let label: String
            @Environment(\.cfTheme) var theme

            var body: some View {
                VStack(spacing: 4) {
                    Rectangle()
                        .fill(color)
                        .frame(width: 50, height: 50)
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(theme.stroke, lineWidth: 1)
                        )
                    Text(label)
                        .font(.caption2)
                        .foregroundColor(theme.textMuted)
                        .frame(width: 50)
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }
}
#endif
