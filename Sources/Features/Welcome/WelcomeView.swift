import SwiftUI

/// The first-run window, built from the Welcome component in `design_handoff_clipflow/design/components/settings.jsx`.
struct WelcomeView: View {
    @Binding var isPresented: Bool
    var onGetStarted: () -> Void
    @ObservedObject private var permissions = PermissionService.shared
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @Environment(\.cfTheme) private var theme

    var body: some View {
        HStack(spacing: 0) {
            heroPanel
            stepsPanel
        }
        .frame(width: 780, height: 520)
    }

    // MARK: - Left

    private var heroPanel: some View {
        ZStack(alignment: .topLeading) {
            CSSRadialGradient(gradient: BrandPalette.welcomePanel, radii: CGSize(width: 1.2, height: 0.8), center: UnitPoint(x: 0.3, y: 0.2))

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    ClipFlowMark(size: 32)
                    Text("ClipFlow").font(.system(size: 18, weight: .semibold)).foregroundColor(.white)
                }
                Text(L("welcome_hero"))
                    .font(.system(size: 28, weight: .semibold))
                    .tracking(-0.28)
                    .lineSpacing(2)
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 26)
                Text(L("welcome_body"))
                    .font(.system(size: 13))
                    .lineSpacing(4)
                    .foregroundColor(CFTheme.dark.textMid)
                    .frame(maxWidth: 280, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
            }
            .padding(32)

            MiniPopoverPreview()
                .scaleEffect(0.78, anchor: .bottomTrailing)
                .rotationEffect(.degrees(-6), anchor: .bottomTrailing)
                .shadow(color: CFTheme.dark.shadowDeep, radius: 25, y: 30)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .offset(x: 40, y: 40)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
                .environment(\.cfTheme, .dark)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipped()
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Right

    private var stepsPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(L("welcome_steps"))
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.08 * 11)
                .textCase(.uppercase)
                .foregroundColor(theme.textSubtle)
                .padding(.bottom, 14)

            CFStepIndicator(number: 1, state: .done, title: L("welcome_step1_title"), bodyText: L("welcome_step1_body"))
            CFStepIndicator(
                number: 2,
                state: permissions.isGranted ? .done : .active,
                title: L("welcome_step2_title"),
                bodyText: L("welcome_step2_body")
            )
            CFStepIndicator(
                number: 3,
                state: permissions.isGranted ? .active : .default,
                title: L("welcome_step3_title"),
                bodyText: L("welcome_step3_body")
            )

            Spacer()

            HStack {
                HStack(spacing: 8) {
                    CFToggle(isOn: Binding(get: { launchAtLogin }, set: { launchAtLogin = LaunchAtLogin.set($0) }))
                        .accessibilityLabel(L("pref_launch_at_login"))
                    Text(L("pref_launch_at_login")).font(.system(size: 12)).foregroundColor(theme.textMuted)
                }
                Spacer()
                HStack(spacing: 8) {
                    CFToolbarBtn(label: L("welcome_skip")) { finish() }
                    CFToolbarBtn(label: permissions.isGranted ? L("welcome_done") : L("welcome_open_settings"), primary: true) {
                        if permissions.isGranted {
                            finish()
                            return
                        }
                        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
                        permissions.request()
                        if !permissions.isGranted { permissions.openSystemSettings() }
                    }
                }
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(theme.surface)
        .onAppear {
            permissions.refresh()
            launchAtLogin = LaunchAtLogin.isEnabled
        }
    }

    private func finish() {
        UserDefaults.standard.set(true, forKey: "hasCompletedWelcome")
        isPresented = false
        onGetStarted()
    }
}

/// The small popover on the Welcome panel: a 260pt dark popover with three sample rows.
private struct MiniPopoverPreview: View {
    @Environment(\.cfTheme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").font(.system(size: 11, weight: .semibold)).foregroundColor(theme.textSubtle)
                Text(L("search_clipboard")).font(.system(size: 13)).foregroundColor(theme.textSubtle)
                Spacer()
                CFKBDChip("⌘F", dim: true)
            }
            .padding(.horizontal, 10)
            .frame(height: 28)
            .background(RoundedRectangle(cornerRadius: 7).fill(theme.inputBg))
            .overlay(RoundedRectangle(cornerRadius: 7).strokeBorder(theme.stroke, lineWidth: 1))
            .padding(EdgeInsets(top: 8, leading: 8, bottom: 6, trailing: 8))

            Text(L("cat_recent"))
                .font(.system(size: 10.5, weight: .semibold))
                .tracking(0.06 * 10.5)
                .textCase(.uppercase)
                .foregroundColor(theme.textLabel)
                .padding(EdgeInsets(top: 6, leading: 14, bottom: 4, trailing: 14))

            row(icon: AnyView(Image(systemName: "link")), title: "github.com/relbns/ClipFlow", subtitle: L("just_now"), kbd: "1", active: true)
            row(icon: AnyView(Image(systemName: "text.alignleft")), title: L("welcome_sample_clip"), subtitle: L("two_minutes"), kbd: "2")
            row(icon: AnyView(RoundedRectangle(cornerRadius: 3).fill(Color.hex(0xFF5733)).frame(width: 14, height: 14)), title: "#FF5733", subtitle: L("clip_hex_color"), kbd: "3")
                .padding(.bottom, 6)
        }
        .frame(width: 260)
        .background(RoundedRectangle(cornerRadius: 12).fill(theme.popoverBg))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color.white.opacity(0.10), lineWidth: 0.5))
    }

    private func row(icon: AnyView, title: String, subtitle: String, kbd: String, active: Bool = false) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 5).fill(theme.fill1)
                icon.font(.system(size: 11, weight: .medium)).foregroundColor(theme.textMid)
            }
            .frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13, weight: active ? .medium : .regular)).foregroundColor(theme.textStrong).lineLimit(1)
                Text(subtitle).font(.system(size: 11)).foregroundColor(theme.textLabel).lineLimit(1)
            }
            Spacer(minLength: 4)
            CFKBDChip(kbd, dim: !active)
        }
        .padding(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
        .background(RoundedRectangle(cornerRadius: 6).fill(active ? Color.hex(0x7874FF, alpha: 0.22) : .clear))
        .padding(.horizontal, 6)
    }
}
