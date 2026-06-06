import SwiftUI

// MARK: - Banner (for accessibility warnings, info messages)
struct CFBanner: View {
    enum Tone {
        case info
        case warn
        case success
        case error
    }

    let tone: Tone
    var icon: AnyView
    let title: String
    let message: String
    var action: AnyView? = nil

    @Environment(\.cfTheme) var theme

    private var colors: (bg: Color, stroke: Color, icon: Color) {
        switch tone {
        case .info:
            return (
                theme.accent.opacity(0.18),
                theme.accent.opacity(0.35),
                theme.accent
            )
        case .warn:
            return (
                theme.warning.opacity(0.20),
                theme.warning.opacity(0.40),
                theme.warning
            )
        case .success:
            return (
                theme.success.opacity(0.18),
                theme.success.opacity(0.35),
                theme.success
            )
        case .error:
            return (
                theme.danger.opacity(0.18),
                theme.danger.opacity(0.35),
                theme.danger
            )
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            icon
                .foregroundColor(colors.icon)
                .frame(width: 18, height: 18)
                .padding(.top, 1)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textStrong)

                Text(message)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textMid)
                    .lineSpacing(1.5)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Action button
            if let action = action {
                action
            }
        }
        .padding(14)
        .background(colors.bg)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(colors.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Convenience Initializers
extension CFBanner {
    static func accessibility(
        title: String = "Accessibility access required",
        message: String = "ClipFlow needs Accessibility permission to watch keystrokes for snippet expansion. Without it, only clipboard history will work.",
        action: AnyView? = nil
    ) -> CFBanner {
        CFBanner(
            tone: .warn,
            icon: AnyView(CFIcon(type: .lock, size: 18, stroke: 1.8)),
            title: title,
            message: message,
            action: action
        )
    }

    static func info(
        icon: AnyView,
        title: String,
        message: String,
        action: AnyView? = nil
    ) -> CFBanner {
        CFBanner(tone: .info, icon: icon, title: title, message: message, action: action)
    }

    static func warn(
        icon: AnyView,
        title: String,
        message: String,
        action: AnyView? = nil
    ) -> CFBanner {
        CFBanner(tone: .warn, icon: icon, title: title, message: message, action: action)
    }

    static func success(
        icon: AnyView,
        title: String,
        message: String,
        action: AnyView? = nil
    ) -> CFBanner {
        CFBanner(tone: .success, icon: icon, title: title, message: message, action: action)
    }

    static func error(
        icon: AnyView,
        title: String,
        message: String,
        action: AnyView? = nil
    ) -> CFBanner {
        CFBanner(tone: .error, icon: icon, title: title, message: message, action: action)
    }
}

// MARK: - Preview
#if DEBUG
struct CFBanner_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BannerShowcase()
                .cfAutoTheme()
                .previewDisplayName("Light")

            BannerShowcase()
                .cfAutoTheme()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }

    struct BannerShowcase: View {
        @Environment(\.cfTheme) var theme

        var body: some View {
            VStack(spacing: 20) {
                Text("ClipFlow Banners")
                    .font(.title2)
                    .bold()
                    .foregroundColor(theme.textStrong)

                VStack(spacing: 16) {
                    CFBanner.accessibility(
                        action: AnyView(
                            CFToolbarBtn(label: "Open System Settings", primary: true)
                        )
                    )

                    CFBanner.info(
                        icon: AnyView(CFIcon(type: .cloud, size: 18, stroke: 1.8)),
                        title: "iCloud sync enabled",
                        message: "Your snippets are automatically backed up to iCloud and synced across devices."
                    )

                    CFBanner.success(
                        icon: AnyView(CFIcon(type: .check, size: 18, stroke: 1.8)),
                        title: "Export complete",
                        message: "Successfully exported 47 snippets to Downloads folder."
                    )

                    CFBanner.error(
                        icon: AnyView(CFIcon(type: .circle, size: 18, stroke: 1.8)),
                        title: "Sync failed",
                        message: "Unable to connect to iCloud. Check your network connection and try again.",
                        action: AnyView(
                            CFToolbarBtn(label: "Retry")
                        )
                    )
                }
                .padding()
                .background(theme.surface)
                .cornerRadius(12)
            }
            .padding(30)
            .frame(width: 650, height: 600)
            .background(theme.surfaceDeep)
        }
    }
}
#endif
