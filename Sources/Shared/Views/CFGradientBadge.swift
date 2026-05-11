import SwiftUI

/// Gradient badge component for Settings tab icons (28×28)
/// Matches design system from Claude Design prototypes
struct CFGradientBadge: View {
    let icon: CFIcon.IconType
    let accent: Color
    let size: CGFloat

    @Environment(\.cfTheme) var theme

    init(icon: CFIcon.IconType, accent: Color, size: CGFloat = 28) {
        self.icon = icon
        self.accent = accent
        self.size = size
    }

    var body: some View {
        ZStack {
            // Gradient background
            // Formula: linear-gradient(180deg, color-mix(accent 65%, white), color-mix(accent 85%, black 10%))
            LinearGradient(
                colors: [
                    mixColor(accent, with: .white, ratio: 0.65),
                    mixColor(accent, with: .black, ratio: 0.85, darken: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))

            // Inset highlight on top edge
            Rectangle()
                .fill(theme.insetHi)
                .frame(height: 1)
                .frame(maxHeight: .infinity, alignment: .top)
                .clipShape(RoundedRectangle(cornerRadius: 7))

            // Icon
            CFIcon(type: icon, size: size * 0.5, stroke: 1.8)
                .foregroundColor(theme.textStrong)
        }
        .frame(width: size, height: size)
    }

    /// Mix two colors with a ratio, approximating CSS color-mix()
    /// - Parameters:
    ///   - base: Base color
    ///   - with: Color to mix with
    ///   - ratio: Ratio of base color (0.0-1.0)
    ///   - darken: Additional darkening factor (0.0-1.0)
    /// - Returns: Mixed color
    private func mixColor(_ base: Color, with mixer: Color, ratio: Double, darken: Double = 0) -> Color {
        // Convert to NSColor for component access (macOS)
        let uiBase = NSColor(base)
        let uiMixer = NSColor(mixer)

        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0

        uiBase.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        uiMixer.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)

        // Mix colors
        let r = r1 * ratio + r2 * (1 - ratio)
        let g = g1 * ratio + g2 * (1 - ratio)
        let b = b1 * ratio + b2 * (1 - ratio)

        // Apply darkening
        let finalR = r * (1 - darken)
        let finalG = g * (1 - darken)
        let finalB = b * (1 - darken)

        return Color(red: Double(finalR), green: Double(finalG), blue: Double(finalB))
    }
}

// MARK: - Preview
#Preview("Gradient Badges - Dark") {
    VStack(spacing: 16) {
        Text("Settings Tab Icons")
            .font(.headline)

        HStack(spacing: 16) {
            VStack(spacing: 4) {
                CFGradientBadge(
                    icon: .gear,
                    accent: Color(red: 0.55, green: 0.03, blue: 0.85)  // General
                )
                Text("General")
                    .font(.system(size: 11))
            }

            VStack(spacing: 4) {
                CFGradientBadge(
                    icon: .star,
                    accent: Color(red: 0.85, green: 0.50, blue: 0.20)  // Appearance
                )
                Text("Appearance")
                    .font(.system(size: 11))
            }

            VStack(spacing: 4) {
                CFGradientBadge(
                    icon: .bolt,
                    accent: Color(red: 0.47, green: 0.44, blue: 1.0)  // Expansion (accent purple)
                )
                Text("Expansion")
                    .font(.system(size: 11))
            }

            VStack(spacing: 4) {
                CFGradientBadge(
                    icon: .key,
                    accent: Color(red: 0.40, green: 0.80, blue: 0.50)  // Hotkeys
                )
                Text("Hotkeys")
                    .font(.system(size: 11))
            }
        }

        HStack(spacing: 16) {
            VStack(spacing: 4) {
                CFGradientBadge(
                    icon: .cloud,
                    accent: Color(red: 0.30, green: 0.60, blue: 1.0)  // Sync
                )
                Text("Sync")
                    .font(.system(size: 11))
            }

            VStack(spacing: 4) {
                CFGradientBadge(
                    icon: .lock,
                    accent: Color(red: 0.35, green: 0.75, blue: 0.85)  // Privacy
                )
                Text("Privacy")
                    .font(.system(size: 11))
            }

            VStack(spacing: 4) {
                CFGradientBadge(
                    icon: .hebrew,
                    accent: Color(red: 0.85, green: 0.40, blue: 0.75)  // Language
                )
                Text("Language")
                    .font(.system(size: 11))
            }
        }
    }
    .padding()
    .background(Color(red: 0.11, green: 0.11, blue: 0.13))
    .cfAutoTheme()
}

#Preview("Gradient Badges - Light") {
    VStack(spacing: 16) {
        Text("Settings Tab Icons")
            .font(.headline)

        HStack(spacing: 16) {
            CFGradientBadge(
                icon: .gear,
                accent: Color(red: 0.55, green: 0.03, blue: 0.85)
            )

            CFGradientBadge(
                icon: .bolt,
                accent: Color(red: 0.47, green: 0.44, blue: 1.0)
            )

            CFGradientBadge(
                icon: .cloud,
                accent: Color(red: 0.30, green: 0.60, blue: 1.0)
            )
        }
    }
    .padding()
    .background(Color(red: 0.96, green: 0.96, blue: 0.97))
    .cfAutoTheme()
}
