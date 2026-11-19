import SwiftUI

/// Welcome/Onboarding screen
/// Matches onboarding-d.png from design handoff
///
/// Specs:
/// - Size: 780×520
/// - Split: 50% visual left, 50% steps right
/// - Left: radial gradient background, hero text, mini-preview
/// - Right: 3 steps, footer with toggle and button
struct WelcomeView: View {
    @Environment(\.cfTheme) var theme
    @Binding var isPresented: Bool
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var currentStep: Int = 2 // Step 2 is "Grant Accessibility"

    var onGetStarted: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left half - Visual
            leftVisualPanel

            // Right half - Steps
            rightStepsPanel
        }
        .frame(width: 780, height: 520)
    }

    // MARK: - Left Visual Panel
    private var leftVisualPanel: some View {
        ZStack {
            CSSRadialGradient(
                gradient: BrandPalette.welcomePanel,
                radii: CGSize(width: 1.2, height: 0.8),
                center: UnitPoint(x: 0.3, y: 0.2)
            )

            VStack(spacing: 0) {
                // Top: Logo + Wordmark
                HStack(spacing: 8) {
                    ClipFlowMark(size: 32)

                    Text("ClipFlow")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.top, 32)
                .padding(.leading, 32)
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                // Center: Hero text
                VStack(spacing: 12) {
                    Text("Everything you copy.\nAnything you type\noften.")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                        .lineSpacing(2)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("A quiet menubar app for clipboard history and abbreviation snippets — with first-class Hebrew & RTL.")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.75))
                        .lineSpacing(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.horizontal, 32)

                Spacer()

                // Bottom-right: Mini preview (rotated -6°, scaled 0.78)
                HStack {
                    Spacer()
                    miniPreview
                        .rotationEffect(.degrees(-6))
                        .scaleEffect(0.78)
                        .padding(.trailing, -20)
                        .padding(.bottom, -10)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Right Steps Panel
    private var rightStepsPanel: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("THREE QUICK STEPS")
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundColor(theme.textLabel)
                    .textCase(.uppercase)
                    .kerning(0.6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(EdgeInsets(top: 32, leading: 32, bottom: 20, trailing: 32))

            // Steps
            VStack(spacing: 8) {
                stepCard(
                    number: 1,
                    state: .done,
                    title: "Pin ClipFlow to your menubar",
                    body: "ClipFlow lives up here — there's no Dock icon. Drag the menubar item to where you'd like."
                )

                stepCard(
                    number: 2,
                    state: .active,
                    title: "Grant Accessibility permission",
                    body: "Required so snippets can expand as you type. We never read passwords or secure fields."
                )

                stepCard(
                    number: 3,
                    state: .idle,
                    title: "Try your first snippet",
                    body: "We've added .dd for today's date. Type it anywhere, then press space."
                )
            }
            .padding(.horizontal, 32)

            Spacer()

            // Footer
            footerView
        }
        .frame(width: 390)
        .background(theme.surfaceDeep)
    }

    // MARK: - Step Card
    enum StepState {
        case done
        case active
        case idle
    }

    @ViewBuilder
    private func stepCard(number: Int, state: StepState, title: String, body: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Badge
            stepBadge(number: number, state: state)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(theme.textStrong)

                Text(body)
                    .font(.system(size: 12))
                    .foregroundColor(theme.textMuted)
                    .lineSpacing(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .background(state == .active ? theme.fillSoft : Color.clear)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(
                    state == .active ? theme.accent.opacity(0.3) : Color.clear,
                    lineWidth: 1
                )
        )
        .cornerRadius(10)
    }

    @ViewBuilder
    private func stepBadge(number: Int, state: StepState) -> some View {
        ZStack {
            if state == .done {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.white)
            } else {
                Text("\(number)")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(state == .active ? .white : theme.textMuted)
            }
        }
        .frame(width: 28, height: 28)
        .background(
            Circle()
                .fill(badgeBackgroundGradient(state: state))
        )
    }

    private func badgeBackgroundGradient(state: StepState) -> LinearGradient {
        switch state {
        case .done:
            return LinearGradient(colors: [BrandPalette.success, BrandPalette.success], startPoint: .top, endPoint: .bottom)
        case .active:
            return LinearGradient(gradient: BrandPalette.stepActive, startPoint: .top, endPoint: .bottom)
        case .idle:
            return LinearGradient(
                colors: [theme.fill1, theme.fill1],
                startPoint: .top,
                endPoint: .bottom
            )
        }
    }

    // MARK: - Footer
    private var footerView: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(theme.stroke)
                .frame(height: 1)

            HStack {
                // Left: Launch at login toggle
                HStack(spacing: 8) {
                    CFCustomToggle(isOn: $launchAtLogin)

                    Text("Launch at login")
                        .font(.system(size: 13))
                        .foregroundColor(theme.text)
                }

                Spacer()

                // Right: Buttons
                HStack(spacing: 8) {
                    Button(action: {
                        // Skip tour - mark as completed
                        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
                        isPresented = false
                    }) {
                        Text("Skip tour")
                            .font(.system(size: 12))
                            .foregroundColor(theme.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        // Mark welcome as completed
                        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
                        onGetStarted()
                        PermissionService.shared.request()
                        if !PermissionService.shared.isGranted {
                            PermissionService.shared.openSystemSettings()
                        }
                    }) {
                        HStack(spacing: 6) {
                            Text("Open System Settings")
                                .font(.system(size: 12, weight: .medium))

                            Image(systemName: "arrow.right")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            LinearGradient(
                                colors: [theme.brandLight, theme.accent],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(6)
                        .shadow(color: theme.accent.opacity(0.3), radius: 3, x: 0, y: 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(EdgeInsets(top: 16, leading: 24, bottom: 16, trailing: 24))
        }
    }

    // MARK: - Mini Preview
    private var miniPreview: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSubtle)

                Text("Search clipboard...")
                    .font(.system(size: 10))
                    .foregroundColor(theme.textSubtle)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(theme.inputBg.opacity(0.5))
            .cornerRadius(5)
            .padding(6)

            // Section
            Text("RECENT")
                .font(.system(size: 8, weight: .semibold))
                .foregroundColor(theme.textLabel)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)

            // Sample clip rows
            VStack(spacing: 2) {
                miniClipRow(icon: "link", text: "github.com/relbns/Clip...")
                miniClipRow(icon: "doc.text", text: "Thanks for the quick...")
            }
            .padding(.horizontal, 4)
            .padding(.bottom, 6)
        }
        .frame(width: 180, height: 140)
        .background(
            theme.popoverBg
                .opacity(0.95)
        )
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.4), radius: 15, x: 0, y: 8)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(Color.white.opacity(0.1), lineWidth: 0.5)
        )
    }

    @ViewBuilder
    private func miniClipRow(icon: String, text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundColor(theme.textMid)
                .frame(width: 16, height: 16)
                .background(theme.fill1)
                .cornerRadius(3)

            Text(text)
                .font(.system(size: 9))
                .foregroundColor(theme.text)
                .lineLimit(1)

            Spacer()

            Text("1")
                .font(.system(size: 8, design: .monospaced))
                .foregroundColor(theme.textSubtle)
                .padding(.horizontal, 3)
                .padding(.vertical, 1)
                .background(theme.fill2)
                .cornerRadius(2)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
    }
}

// MARK: - Preview
#if DEBUG
struct WelcomeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            WelcomeView(isPresented: .constant(true)) {
            }
            .cfAutoTheme()
            .previewDisplayName("Welcome - Light")

            WelcomeView(isPresented: .constant(true)) {
            }
            .cfAutoTheme()
            .preferredColorScheme(.dark)
            .previewDisplayName("Welcome - Dark")
        }
    }
}
#endif
