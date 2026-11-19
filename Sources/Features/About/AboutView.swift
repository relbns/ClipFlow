import SwiftUI

/// The About window, built from `design_handoff_clipflow/design/components/about.jsx`.
struct AboutView: View {
    @Environment(\.openURL) private var openURL
    @Environment(\.cfTheme) private var theme

    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            ClipFlowHero(size: 128)

            Text("ClipFlow")
                .font(.system(size: 28, weight: .bold))
                .tracking(-0.28)
                .foregroundColor(theme.textStrong)
                .padding(.top, 22)
            Text(L("app_tagline"))
                .font(.system(size: 13.5))
                .foregroundColor(theme.textMuted)
                .padding(.top, 4)

            HStack(spacing: 8) {
                Text(L("version_format", version))
                    .font(.system(size: 12))
                    .foregroundColor(theme.textSubtle)
                Text(L("alpha_badge"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .tracking(0.06 * 10.5)
                    .textCase(.uppercase)
                    .foregroundColor(BrandPalette.warningText)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(BrandPalette.warning.mixed(25)))
            }
            .padding(.top, 10)

            Rectangle().fill(theme.strokeSoft).frame(height: 1).padding(.top, 24).padding(.bottom, 16)

            VStack(alignment: .leading, spacing: 0) {
                Text(L("credits"))
                    .font(.system(size: 10.5, weight: .bold))
                    .tracking(0.08 * 10.5)
                    .textCase(.uppercase)
                    .foregroundColor(theme.textLabel)
                    .padding(.bottom, 4)
                CreditRow(symbol: "person", accent: BrandPalette.Credit.creator, name: "Ariel Benesh", role: L("credit_creator_role"))
                Text(L("credits_giants"))
                    .font(.system(size: 11.5))
                    .foregroundColor(theme.textMuted)
                    .padding(.top, 14)
                    .padding(.bottom, 4)
                CreditRow(symbol: "scissors", accent: BrandPalette.Credit.clipy, name: "Clipy", role: L("credit_clipy_role"))
                CreditRow(symbol: "list.clipboard", accent: BrandPalette.Credit.flycut, name: "Flycut", role: L("credit_flycut_role"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 10)

            VStack(spacing: 12) {
                HStack(spacing: 6) {
                    AboutLink(symbol: "link", label: "GitHub", url: "https://github.com/relbns/ClipFlow")
                    AboutLink(symbol: "text.alignleft", label: L("full_credits"), url: "https://github.com/relbns/ClipFlow/blob/main/CREDITS.md")
                    AboutLink(symbol: "gearshape", label: L("license"), url: "https://github.com/relbns/ClipFlow/blob/main/LICENSE")
                }
                Text(L("about_footer"))
                    .font(.system(size: 11))
                    .foregroundColor(theme.textFaint)
            }
            .padding(.top, 18)
            .frame(maxWidth: .infinity)
            .overlay(Rectangle().fill(theme.strokeSoft).frame(height: 1), alignment: .top)
        }
        .padding(EdgeInsets(top: 36, leading: 32, bottom: 22, trailing: 32))
        .frame(width: 560, height: 680)
        .background(theme.surface)
    }
}

private struct CreditRow: View {
    let symbol: String
    let accent: Color
    let name: String
    let role: String
    @Environment(\.cfTheme) private var theme

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 8).fill(accent.mixed(22))
                Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundColor(accent)
            }
            .frame(width: 28, height: 28)
            .frame(width: 32, alignment: .leading)
            VStack(alignment: .leading, spacing: 1) {
                Text(name).font(.system(size: 13, weight: .medium)).foregroundColor(theme.textStrong)
                Text(role).font(.system(size: 12)).foregroundColor(theme.textMuted)
            }
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
    }
}

private struct AboutLink: View {
    let symbol: String
    let label: String
    let url: String
    @Environment(\.openURL) private var openURL

    var body: some View {
        Button {
            if let destination = URL(string: url) { openURL(destination) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: symbol).font(.system(size: 12, weight: .medium))
                Text(label).font(.system(size: 13, weight: .medium))
            }
            .foregroundColor(BrandPalette.accentLink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
