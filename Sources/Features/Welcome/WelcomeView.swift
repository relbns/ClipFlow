import SwiftUI

struct WelcomeView: View {
    @Environment(\.cfTheme) var theme
    @Binding var isPresented: Bool

    var onGetStarted: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 32) {
                    // Hero Icon
                    ClipFlowMark.heroIcon(size: 128)
                        .padding(.top, 60)

                    // Title & Tagline
                    VStack(spacing: 12) {
                        Text("Welcome to ClipFlow")
                            .font(.system(size: 32, weight: .bold))
                            .foregroundColor(theme.textStrong)

                        Text("Modern clipboard manager + text expander")
                            .font(.system(size: 15))
                            .foregroundColor(theme.textMid)
                    }

                    // Feature Cards
                    VStack(spacing: 16) {
                        FeatureCard(
                            icon: AnyView(CFIcon(type: .clock, size: 20, stroke: 1.8)),
                            iconColor: Color(red: 0.78, green: 0.14, blue: 0.70),
                            title: "Clipboard History",
                            description: "Access your clipboard history with ⌘⇧V. Never lose copied text, images, or files again."
                        )

                        FeatureCard(
                            icon: AnyView(CFIcon(type: .bolt, size: 20, stroke: 1.8)),
                            iconColor: Color(red: 0.74, green: 0.14, blue: 0.60),
                            title: "Text Expansion",
                            description: "Create custom snippets with variables, prompts, and date formatting. Type less, accomplish more."
                        )

                        FeatureCard(
                            icon: AnyView(CFIcon(type: .lock, size: 20, stroke: 1.8)),
                            iconColor: Color(red: 0.85, green: 0.15, blue: 0.30),
                            title: "Privacy First",
                            description: "Exclude password managers and sensitive apps. Your data stays on your Mac."
                        )
                    }
                    .padding(.horizontal, 40)

                    // Accessibility Notice
                    VStack(spacing: 16) {
                        CFBanner.accessibility(
                            title: "Accessibility permission required",
                            message: "ClipFlow needs Accessibility access to enable text expansion. You can grant this permission in System Settings after setup.",
                            action: nil
                        )
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 40)
                }
            }

            // Footer with action button
            VStack(spacing: 16) {
                Rectangle()
                    .fill(theme.strokeSoft)
                    .frame(height: 1)

                HStack {
                    Spacer()

                    CFToolbarBtn(
                        icon: AnyView(CFIcon(type: .chevron, size: 12, stroke: 1.8)),
                        label: "Get Started",
                        primary: true
                    ) {
                        onGetStarted()
                        isPresented = false
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(theme.surface)
        }
        .frame(width: 580, height: 720)
        .background(theme.surfaceDeep)
    }
}

// MARK: - Feature Card Component
private struct FeatureCard: View {
    let icon: AnyView
    let iconColor: Color
    let title: String
    let description: String

    @Environment(\.cfTheme) var theme

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(iconColor.opacity(0.18))
                    .frame(width: 44, height: 44)

                icon
                    .foregroundColor(iconColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(theme.textStrong)

                Text(description)
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSubtle)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .background(theme.surface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.stroke, lineWidth: 1)
        )
    }
}

// MARK: - Preview
#Preview {
    WelcomeView(isPresented: .constant(true)) {
        print("Get Started tapped")
    }
    .cfAutoTheme()
}
