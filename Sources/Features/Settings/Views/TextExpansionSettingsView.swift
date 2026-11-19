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
    @ObservedObject private var permissions = PermissionService.shared

    var body: some View {
        Group {
            if permissions.isGranted {
                CFBanner.success(
                    icon: AnyView(CFIcon(type: .check, size: 18, stroke: 1.8)),
                    title: "Permissions granted",
                    message: "ClipFlow can expand snippets and paste into other apps."
                )
            } else {
                CFBanner.accessibility(
                    title: "Accessibility and Input Monitoring required",
                    message: "ClipFlow needs both permissions to expand snippets as you type and to paste the item you pick. Without them, only clipboard history works.",
                    action: AnyView(
                        CFToolbarBtn(
                            label: "Open System Settings",
                            primary: true
                        ) {
                            permissions.request()
                            if !permissions.isGranted {
                                permissions.openSystemSettings()
                            }
                        }
                    )
                )
            }
        }
        .onAppear {
            permissions.refresh()
        }
    }
}

#Preview {
    TextExpansionSettingsView()
        .cfAutoTheme()
}
