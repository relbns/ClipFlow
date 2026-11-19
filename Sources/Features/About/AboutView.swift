import SwiftUI
import AppKit

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.cfTheme) var theme

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Spacer().frame(height: 20)

                    ClipFlowHero(size: 128)

                    Spacer().frame(height: 12)

                    // Title
                    Text("ClipFlow")
                        .font(.system(size: 28, weight: .bold))
                        .kerning(-0.28)
                        .foregroundColor(theme.textStrong)

                    Spacer().frame(height: 4)

                    // Tagline
                    Text("Modern clipboard manager + text expander")
                        .font(.system(size: 13.5))
                        .foregroundColor(theme.textMuted)

                    Spacer().frame(height: 10)

                    // Version Row
                    HStack(spacing: 8) {
                        Text("Version 1.0.0")
                            .font(.system(size: 13))
                            .foregroundColor(theme.text)

                        // ALPHA badge - amber/gold color
                        Text("ALPHA")
                            .font(.system(size: 10.5, weight: .semibold))
                            .foregroundColor(BrandPalette.warningText)
                            .textCase(.uppercase)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(
                                BrandPalette.warning.mixed(25)
                            )
                            .cornerRadius(4)
                    }

                    Spacer().frame(height: 16)

                    // Divider
                    Rectangle()
                        .fill(theme.stroke)
                        .frame(height: 1)
                        .frame(width: 460)

                    Spacer().frame(height: 12)

                    // Credits Section
                    VStack(alignment: .leading, spacing: 0) {
                        // Header
                        Text("CREDITS")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(theme.textLabel)
                            .kerning(0.66)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Spacer().frame(height: 8)

                        // Ariel Benesh
                        CreditRow(
                            icon: AnyView(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 14, weight: .medium))
                            ),
                            iconColor: BrandPalette.Credit.creator,
                            title: "Ariel Benesh",
                            subtitle: "Creator & Developer"
                        )

                        Spacer().frame(height: 10)

                        // Separator
                        Text("Built on the shoulders of giants")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textSubtle)
                            .padding(.leading, 40)

                        Spacer().frame(height: 8)

                        // Clipy
                        CreditRow(
                            icon: AnyView(
                                Image(systemName: "curlybraces")
                                    .font(.system(size: 14, weight: .medium))
                            ),
                            iconColor: BrandPalette.Credit.clipy,
                            title: "Clipy",
                            subtitle: "Core clipboard architecture"
                        )

                        Spacer().frame(height: 6)

                        // Flycut
                        CreditRow(
                            icon: AnyView(
                                Image(systemName: "paintbrush.fill")
                                    .font(.system(size: 14, weight: .medium))
                            ),
                            iconColor: BrandPalette.Credit.flycut,
                            title: "Flycut",
                            subtitle: "UI/UX inspiration for Simple mode"
                        )
                    }
                    .padding(.horizontal, 50)

                    Spacer().frame(height: 16)

                    // Divider
                    Rectangle()
                        .fill(theme.stroke)
                        .frame(height: 1)
                        .frame(width: 460)

                    Spacer().frame(height: 12)

                    // Footer Links
                    HStack(spacing: 20) {
                        Button(action: {
                            if let url = URL(string: "https://github.com/relbns/ClipFlow") {
                                openURL(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "link")
                                    .font(.system(size: 11, weight: .medium))
                                Text("GitHub")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(BrandPalette.accentLink)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            if let url = URL(string: "https://github.com/relbns/ClipFlow/blob/main/CREDITS.md") {
                                openURL(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11, weight: .medium))
                                Text("Full Credits")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(BrandPalette.accentLink)
                        }
                        .buttonStyle(.plain)

                        Button(action: {
                            if let url = URL(string: "https://github.com/relbns/ClipFlow/blob/main/LICENSE") {
                                openURL(url)
                            }
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "gearshape")
                                    .font(.system(size: 11, weight: .medium))
                                Text("License")
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(BrandPalette.accentLink)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer().frame(height: 8)

                    // Copyright
                    Text("© 2026 ClipFlow")
                        .font(.system(size: 11))
                        .foregroundColor(theme.textFaint)

                    Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 560, height: 520)
        .background(theme.surfaceDeep)
    }
}

// MARK: - Credit Row
private struct CreditRow: View {
    let icon: AnyView
    let iconColor: Color
    let title: String
    let subtitle: String

    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(spacing: 12) {
            // Icon tile
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.mixed(22))
                    .frame(width: 28, height: 28)

                icon
                    .foregroundColor(iconColor)
            }

            // Text
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textStrong)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSubtle)
            }

            Spacer()
        }
    }
}

#Preview {
    AboutView()
        .cfAutoTheme()
}
