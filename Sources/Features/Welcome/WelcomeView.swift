import SwiftUI

struct WelcomeView: View {
    @Environment(\.cfTheme) var theme
    @Binding var isPresented: Bool
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @State private var currentStep: Int = 1

    var onGetStarted: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            // Left Column - Hero Section with Gradient
            leftColumn

            // Right Column - Steps & Actions
            rightColumn
        }
        .frame(width: 780, height: 560)
        .background(theme.surfaceDeep)
    }

    // MARK: - Left Column
    private var leftColumn: some View {
        ZStack {
            // Radial gradient background
            RadialGradient(
                colors: [
                    Color(red: 0.55, green: 0.19, blue: 0.72).opacity(0.20),  // Purple accent
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 50,
                endRadius: 400
            )
            .background(theme.surface)

            VStack(spacing: 32) {
                Spacer()

                // Hero Icon
                ClipFlowMark.heroIcon(size: 96)

                // Hero Text
                VStack(spacing: 12) {
                    Text("Welcome to\nClipFlow")
                        .font(.system(size: 36, weight: .bold))
                        .foregroundColor(theme.textStrong)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)

                    Text("Clipboard manager + text expander")
                        .font(.system(size: 14))
                        .foregroundColor(theme.textSubtle)
                }

                // Mini Preview Card
                miniPreviewCard

                Spacer()
            }
            .padding(40)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Right Column
    private var rightColumn: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 8) {
                Text("Get Started")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(theme.textStrong)

                Text("Follow these quick steps to set up ClipFlow")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textSubtle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(EdgeInsets(top: 32, leading: 32, bottom: 24, trailing: 32))

            // Steps
            ScrollView {
                VStack(spacing: 12) {
                    CFStepIndicator(
                        number: 1,
                        state: currentStep > 1 ? .done : (currentStep == 1 ? .active : .default),
                        title: "Pin ClipFlow to your menubar",
                        bodyText: "ClipFlow lives up here — there's no Dock icon. Drag the menubar item to where you'd like."
                    )

                    CFStepIndicator(
                        number: 2,
                        state: currentStep > 2 ? .done : (currentStep == 2 ? .active : .default),
                        title: "Grant Accessibility permission",
                        bodyText: "Required so snippets can expand as you type. We never read passwords or secure fields."
                    )

                    CFStepIndicator(
                        number: 3,
                        state: currentStep > 3 ? .done : (currentStep == 3 ? .active : .default),
                        title: "Try your first snippet",
                        bodyText: "We've added .dd for today's date. Type it anywhere, then press space."
                    )
                }
                .padding(.horizontal, 32)
            }

            Spacer()

            // Launch at Login Toggle
            HStack(spacing: 12) {
                CFToggle(isOn: $launchAtLogin)

                Text("Launch ClipFlow at login")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMid)

                Spacer()
            }
            .padding(EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32))
            .background(theme.fillSoft)

            // Footer with action
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
            .padding(EdgeInsets(top: 16, leading: 32, bottom: 24, trailing: 32))
        }
        .frame(width: 390)
        .background(theme.surfaceDeep)
    }

    // MARK: - Mini Preview Card
    private var miniPreviewCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Simulated menubar item
            HStack(spacing: 8) {
                CFIcon(type: .clock, size: 12, stroke: 1.6)
                    .foregroundColor(theme.textMuted)

                Text("⌘⇧V")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(theme.textSubtle)

                Spacer()

                Circle()
                    .fill(Color(red: 0.47, green: 0.44, blue: 1.0))
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(theme.fill1)
            .cornerRadius(5)

            Text("Quick access to clipboard\nhistory and snippets")
                .font(.system(size: 11))
                .foregroundColor(theme.textMuted)
                .lineSpacing(2)
        }
        .padding(16)
        .frame(maxWidth: 240)
        .background(theme.fillSoft)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.strokeSoft, lineWidth: 1)
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
