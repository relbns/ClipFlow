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
                        .foregroundColor(theme.textStrong)

                    Text(L("app_tagline"))
                        .font(.system(size: 14))
                        .foregroundColor(theme.textMid)
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
                    Text(L("credits"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textStrong)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    // Creator
                    CreditRow(
                        icon: AnyView(CFIcon(type: .sparkles, size: 18, stroke: 1.8)),
                        iconColor: Color(red: 0.78, green: 0.14, blue: 0.70),
                        title: "Ariel Benesh",
                        description: "Creator & Developer",
                        link: "https://github.com/relbns",
                        openURL: openURL
                    )

                    // Built on giants separator
                    Text("Built on the shoulders of giants:")
                        .font(.system(size: 12))
                        .foregroundColor(theme.textSubtle)
                        .padding(.leading, 30)
                        .padding(.top, 4)

                    // Clipy
                    CreditRow(
                        icon: AnyView(CFIcon(type: .bracket, size: 18, stroke: 1.8)),
                        iconColor: Color(red: 0.74, green: 0.14, blue: 0.60),
                        title: "Clipy",
                        description: "Core clipboard architecture",
                        link: "https://github.com/Clipy/Clipy",
                        openURL: openURL
                    )

                    // Flycut
                    CreditRow(
                        icon: AnyView(CFIcon(type: .bolt, size: 18, stroke: 1.8)),
                        iconColor: Color(red: 0.78, green: 0.14, blue: 0.50),
                        title: "Flycut",
                        description: "UI/UX inspiration",
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
                    CFLinkBtn(
                        icon: AnyView(CFIcon(type: .link, size: 13, stroke: 1.8)),
                        label: "GitHub"
                    ) {
                        if let url = URL(string: "https://github.com/relbns/ClipFlow") {
                            openURL(url)
                        }
                    }

                    CFLinkBtn(
                        icon: AnyView(CFIcon(type: .text, size: 13, stroke: 1.8)),
                        label: L("full_credits")
                    ) {
                        if let url = URL(string: "https://github.com/relbns/ClipFlow/blob/main/CREDITS.md") {
                            openURL(url)
                        }
                    }

                    CFLinkBtn(
                        icon: AnyView(CFIcon(type: .gear, size: 13, stroke: 1.8)),
                        label: "License"
                    ) {
                        if let url = URL(string: "https://github.com/relbns/ClipFlow/blob/main/LICENSE") {
                            openURL(url)
                        }
                    }
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
                    .frame(width: 32, height: 32)

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
