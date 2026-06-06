import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.cfTheme) var theme

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Hero Icon
                ClipFlowMark.heroIcon(size: 128)
                    .padding(.top, 40)

                // Title & Tagline
                VStack(spacing: 8) {
                    Text("ClipFlow")
                        .font(.system(size: 28, weight: .bold))
                        .kerning(-0.28)  // letter-spacing -.01em
                        .foregroundColor(theme.textStrong)

                    Text("Modern clipboard manager + text expander")
                        .font(.system(size: 13.5))
                        .foregroundColor(theme.textMuted)
                }

                // Version Badge
                HStack(spacing: 8) {
                    Text("Version 1.0.0")
                        .font(.system(size: 13))
                        .foregroundColor(theme.text)

                    CFVersionTag(type: .alpha)
                }
                .padding(.bottom, 8)

                // Divider
                Rectangle()
                    .fill(theme.strokeSoft)
                    .frame(height: 1)
                    .frame(maxWidth: 460)

                // Credits Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("CREDITS")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(theme.textLabel)
                        .textCase(.uppercase)
                        .tracking(0.06 * 11)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Creator
                    CreditRow(
                        icon: AnyView(
                            Image(systemName: "person.fill")
                                .font(.system(size: 16, weight: .medium))
                        ),
                        iconColor: theme.accent,
                        title: "Ariel Benesh",
                        description: "Creator & Developer",
                        link: "https://github.com/relbns",
                        openURL: openURL
                    )

                    // Built on giants separator
                    Text("Built on the shoulders of giants")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSubtle)
                        .padding(.leading, 36)
                        .padding(.top, 4)

                    // Clipy
                    CreditRow(
                        icon: AnyView(
                            Image(systemName: "curlybraces")
                                .font(.system(size: 16, weight: .medium))
                        ),
                        iconColor: theme.success,
                        title: "Clipy",
                        description: "Core clipboard architecture",
                        link: "https://github.com/Clipy/Clipy",
                        openURL: openURL
                    )

                    // Flycut
                    CreditRow(
                        icon: AnyView(
                            Image(systemName: "paintbrush.fill")
                                .font(.system(size: 16, weight: .medium))
                        ),
                        iconColor: theme.warning,
                        title: "Flycut",
                        description: "UI/UX inspiration for Simple mode",
                        link: "https://github.com/TermiT/Flycut",
                        openURL: openURL
                    )
                }
                .padding(.horizontal, 50)

                // Divider
                Rectangle()
                    .fill(theme.strokeSoft)
                    .frame(height: 1)
                    .frame(maxWidth: 460)
                    .padding(.top, 8)

                // Footer Links
                HStack(spacing: 16) {
                    Button(action: {
                        if let url = URL(string: "https://github.com/relbns/ClipFlow") {
                            openURL(url)
                        }
                    }) {
                        Text("🔗 GitHub")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let url = URL(string: "https://github.com/relbns/ClipFlow/blob/main/CREDITS.md") {
                            openURL(url)
                        }
                    }) {
                        Text("📄 Full Credits")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        if let url = URL(string: "https://github.com/relbns/ClipFlow/blob/main/LICENSE") {
                            openURL(url)
                        }
                    }) {
                        Text("⚙️ License")
                            .font(.system(size: 12))
                            .foregroundColor(theme.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 4)

                // Copyright
                Text("© 2026 ClipFlow · Made with care in Tel Aviv")
                    .font(.system(size: 11))
                    .foregroundColor(theme.textFaint)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
            .frame(maxWidth: .infinity)
        }
        .frame(width: 560, height: 680)
        .background(theme.surfaceDeep)
    }
}

// MARK: - Credit Row Component
private struct CreditRow: View {
    let icon: AnyView
    let iconColor: Color
    let title: String
    let description: String
    let link: String
    let openURL: OpenURLAction

    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 28, height: 28)

                icon
                    .foregroundColor(iconColor)
            }

            // Text content
            VStack(alignment: .leading, spacing: 3) {
                Button(action: {
                    if let url = URL(string: link) {
                        openURL(url)
                    }
                }) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(theme.textStrong)
                }
                .buttonStyle(.plain)

                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSubtle)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AboutView()
        .cfAutoTheme()
}
