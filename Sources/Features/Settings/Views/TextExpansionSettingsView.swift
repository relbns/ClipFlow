import SwiftUI

struct TextExpansionSettingsView: View {
    @AppStorage("textExpansionEnabled") private var expansionEnabled = true
    @AppStorage("expandAfter") private var expandAfter = "delimiter"
    @AppStorage("playSoundOnExpand") private var playSound = false
    @AppStorage("showNotificationOnExpand") private var showNotification = false
    @AppStorage("backspaceCancels") private var backspaceCancels = true
    @AppStorage("livePreview") private var livePreview = false

    @Environment(\.cfTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("text_expansion"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.textStrong)

                    Text("Automatically expand abbreviations as you type")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSubtle)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Settings Rows
                VStack(spacing: 0) {
                    CFSettingsRow(
                        label: "Enable text expansion",
                        hint: "Turn on/off snippet expansion globally"
                    ) {
                        CFToggle(isOn: $expansionEnabled)
                    }

                    CFSettingsRow(
                        label: "Expand after",
                        hint: "Character that triggers snippet expansion"
                    ) {
                        CFSegmentedControl(
                            selection: Binding(
                                get: {
                                    ["delimiter", "space", "tab", "enter", "any"].firstIndex(of: expandAfter) ?? 0
                                },
                                set: { index in
                                    expandAfter = ["delimiter", "space", "tab", "enter", "any"][index]
                                }
                            ),
                            options: ["Delimiter", "Space", "Tab", "Enter", "Any"],
                            columns: 3
                        )
                    }

                    CFSettingsRow(
                        label: "Play sound on expansion",
                        hint: "Quiet click when a snippet expands"
                    ) {
                        CFToggle(isOn: $playSound)
                    }

                    CFSettingsRow(
                        label: "Backspace cancels",
                        hint: "Press backspace immediately after expansion to revert to the abbreviation"
                    ) {
                        CFToggle(isOn: $backspaceCancels)
                    }

                    CFSettingsRow(
                        label: "Show brief notification",
                        hint: "Display a subtle notification on expansion"
                    ) {
                        CFToggle(isOn: $showNotification)
                    }

                    CFSettingsRow(
                        label: "Live preview",
                        hint: "See your snippet rendered with current variables before it fires",
                        isLast: true
                    ) {
                        HStack(spacing: 8) {
                            CFToggle(isOn: $livePreview)
                            Text("Floating preview · 200 ms hold")
                                .font(.system(size: 12))
                                .foregroundColor(theme.textMuted)
                        }
                    }
                }
                .padding(20)
                .background(theme.surface)
                .cornerRadius(12)
                .padding(.horizontal, 24)

                // Permission Banner
                PermissionStatusView()
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
            }
        }
        .background(theme.surfaceDeep)
    }
}

struct PermissionStatusView: View {
    @State private var hasAccessibility = AXIsProcessTrusted()

    var body: some View {
        Group {
            if hasAccessibility {
                CFBanner.success(
                    icon: AnyView(CFIcon(type: .check, size: 18, stroke: 1.8)),
                    title: "Accessibility permission granted",
                    message: "ClipFlow can monitor keystrokes for text expansion."
                )
            } else {
                CFBanner.accessibility(
                    title: "Accessibility permission required",
                    message: "ClipFlow needs Accessibility access to enable text expansion. Without it, snippets won't expand as you type.",
                    action: AnyView(
                        CFToolbarBtn(
                            label: "Open System Settings",
                            primary: true
                        ) {
                            openAccessibilitySettings()
                        }
                    )
                )
            }
        }
        .onAppear {
            hasAccessibility = AXIsProcessTrusted()
        }
    }

    private func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)

        // Recheck after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            hasAccessibility = AXIsProcessTrusted()
        }
    }
}

#Preview {
    TextExpansionSettingsView()
        .cfAutoTheme()
}
