import SwiftUI

struct AboutView: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 20) {
            // App Icon
            if let appIcon = NSImage(named: "AppIcon") {
                Image(nsImage: appIcon)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .cornerRadius(22)
                    .shadow(radius: 4)
            } else {
                Image(systemName: "doc.on.clipboard.fill")
                    .resizable()
                    .frame(width: 100, height: 100)
                    .foregroundColor(.blue)
            }

            // App Name & Version
            VStack(spacing: 4) {
                Text("ClipFlow")
                    .font(.system(size: 32, weight: .bold))

                Text(L("app_tagline"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Version 1.0.0 (Alpha)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 4)
            }

            Divider()
                .padding(.horizontal, 40)

            // Credits
            VStack(alignment: .leading, spacing: 12) {
                Text(L("credits"))
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Created By
                creditRow(
                    icon: "person.circle.fill",
                    title: "Ariel Benesh",
                    description: "Creator & Developer",
                    link: "https://github.com/relbns"
                )

                Divider()
                    .padding(.vertical, 4)

                Text("Built on the shoulders of giants:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 36)

                creditRow(
                    icon: "scissors",
                    title: "Clipy",
                    description: "Core clipboard architecture",
                    link: "https://github.com/Clipy/Clipy"
                )

                creditRow(
                    icon: "doc.on.doc",
                    title: "Flycut",
                    description: "UI/UX inspiration",
                    link: "https://github.com/TermiT/Flycut"
                )
            }
            .padding(.horizontal, 30)

            Divider()
                .padding(.horizontal, 40)

            // Links
            HStack(spacing: 20) {
                Button(action: {
                    if let url = URL(string: "https://github.com/relbns/ClipFlow") {
                        openURL(url)
                    }
                }) {
                    Label("GitHub", systemImage: "link")
                }
                .buttonStyle(.link)

                Button(action: {
                    if let url = URL(string: "https://github.com/relbns/ClipFlow/blob/main/CREDITS.md") {
                        openURL(url)
                    }
                }) {
                    Label(L("full_credits"), systemImage: "doc.text")
                }
                .buttonStyle(.link)

                Button(action: {
                    if let url = URL(string: "https://github.com/relbns/ClipFlow/blob/main/LICENSE") {
                        openURL(url)
                    }
                }) {
                    Label("License", systemImage: "doc.badge.gearshape")
                }
                .buttonStyle(.link)
            }
            .padding(.bottom, 10)
        }
        .frame(width: 480, height: 600)
        .padding(.vertical, 30)
    }

    @ViewBuilder
    private func creditRow(icon: String, title: String, description: String, link: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .frame(width: 24)
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                Button(action: {
                    if let url = URL(string: link) {
                        openURL(url)
                    }
                }) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(.link)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview {
    AboutView()
}
