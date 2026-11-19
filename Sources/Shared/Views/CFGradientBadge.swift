import SwiftUI

/// Gradient badge for Settings tabs (28×28)
/// Features:
/// - Gradient background based on accent color
/// - Inset highlight on top edge
/// - Icon centered
struct CFGradientBadge: View {
    let icon: CFIcon.IconType
    let accent: Color
    var size: CGFloat = 28

    @Environment(\.cfTheme) var theme

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    accent.opacity(0.65), // Top: lighter
                    accent.opacity(0.85)  // Bottom: darker
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(width: size, height: size)
            .cornerRadius(7)

            // Inset highlight (top edge)
            VStack {
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: size * 0.4)
                Spacer()
            }
            .frame(width: size, height: size)
            .cornerRadius(7)
            .blendMode(.overlay)

            // Icon
            CFIcon(type: icon, size: size * 0.5, stroke: 1.8)
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .shadow(
            color: Color.black.opacity(0.15),
            radius: 2,
            x: 0,
            y: 1
        )
    }
}

#Preview("Light") {
    HStack(spacing: 16) {
        CFGradientBadge(
            icon: .gear,
            accent: BrandPalette.SettingsTab.general
        )
        CFGradientBadge(
            icon: .star,
            accent: BrandPalette.SettingsTab.appearance
        )
        CFGradientBadge(
            icon: .bolt,
            accent: BrandPalette.SettingsTab.expansion
        )
    }
    .padding(40)
    .cfAutoTheme()
}
