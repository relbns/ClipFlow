import SwiftUI

struct SettingsView: View {
    @State private var selectedTab: Int
    @Environment(\.cfTheme) var theme

    init(initialTab: Int = 0) {
        _selectedTab = State(initialValue: initialTab)
    }

    // Tab configuration with OKLCH accent colors
    private let tabs: [(icon: CFIcon.IconType, label: String, accent: Color)] = [
        (.gear, "General", BrandPalette.SettingsTab.general),
        (.star, "Appearance", BrandPalette.SettingsTab.appearance),
        (.bolt, "Expansion", BrandPalette.SettingsTab.expansion),
        (.key, "Hotkeys", BrandPalette.SettingsTab.hotkeys),
        (.cloud, "Sync", BrandPalette.SettingsTab.sync),
        (.lock, "Privacy", BrandPalette.SettingsTab.privacy),
        (.hebrew, "Language", BrandPalette.SettingsTab.language)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Custom Tab Bar
            HStack(spacing: 4) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: { selectedTab = index }) {
                        VStack(spacing: 4) {
                            CFGradientBadge(icon: tab.icon, accent: tab.accent)
                            Text(tab.label)
                                .font(.system(size: 11))
                                .foregroundColor(selectedTab == index ? theme.textStrong : theme.textMid)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedTab == index ? theme.fill1 : Color.clear)
                        .cornerRadius(7)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.titlebarBg)

            // Content
            Group {
                switch selectedTab {
                case 0: GeneralSettingsView()
                case 1: AppearanceSettingsView()
                case 2: TextExpansionSettingsView()
                case 3: HotkeySettingsView()
                case 4: SyncSettingsView()
                case 5: PrivacySettingsView()
                case 6: LanguageSettingsView()
                default: EmptyView()
                }
            }
        }
        .frame(width: 760, height: 620)
    }
}

struct GeneralSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("preferredLanguage") private var preferredLanguage = "system"
    @AppStorage("launchAtLogin") private var launchAtLogin = false
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 30.0
    @AppStorage("removeDuplicates") private var removeDuplicates = true
    @AppStorage("moveUsedToTop") private var moveUsedToTop = true
    @AppStorage("startMonitoring") private var startMonitoring = true

    @Environment(\.cfTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        ClipFlowMark(size: 48)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("ClipFlow")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(theme.textStrong)

                            Text(L("app_tagline"))
                                .font(.system(size: 12))
                                .foregroundColor(theme.textSubtle)
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Settings Rows
                VStack(spacing: 0) {
                    CFSettingsRow(
                        label: L("interface_language"),
                        hint: preferredLanguage == "system" ? L("system_default") : (preferredLanguage == "he" ? L("hebrew") : L("english"))
                    ) {
                        CFSegmentedControl(
                            selection: Binding(
                                get: {
                                    ["system", "en", "he"].firstIndex(of: preferredLanguage) ?? 0
                                },
                                set: { index in
                                    preferredLanguage = ["system", "en", "he"][index]
                                    languageManager.setLanguage(preferredLanguage)
                                }
                            ),
                            options: [L("system_default"), L("english"), L("hebrew")],
                            columns: 3
                        )
                    }

                    CFSettingsRow(
                        label: L("maximum_items"),
                        hint: "Number of clipboard items to keep in history"
                    ) {
                        CFSlider(value: $maxHistoryItems, range: 10...100, displayValue: "\(Int(maxHistoryItems))")
                    }

                    CFSettingsRow(
                        label: L("remove_duplicates"),
                        hint: "Automatically remove duplicate clipboard entries"
                    ) {
                        CFToggle(isOn: $removeDuplicates)
                    }

                    CFSettingsRow(
                        label: L("move_used_to_top"),
                        hint: "Move recently used items to the top of history"
                    ) {
                        CFToggle(isOn: $moveUsedToTop)
                    }

                    CFSettingsRow(
                        label: L("launch_at_login"),
                        hint: "Start ClipFlow automatically when you log in"
                    ) {
                        CFToggle(isOn: $launchAtLogin)
                    }

                    CFSettingsRow(
                        label: L("start_monitoring"),
                        hint: "Begin monitoring clipboard on launch",
                        isLast: true
                    ) {
                        CFToggle(isOn: $startMonitoring)
                    }
                }
                .padding(20)
                .background(theme.surface)
                .cornerRadius(12)
                .padding(.horizontal, 24)

                // About Section
                VStack(alignment: .leading, spacing: 12) {
                    Text(L("about"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(theme.textStrong)

                    HStack {
                        Text("Version 1.0.0")
                            .font(.system(size: 13))
                            .foregroundColor(theme.text)

                        CFVersionTag(type: .alpha)

                        Spacer()

                        CFLinkBtn(
                            icon: AnyView(CFIcon(type: .sparkles, size: 13)),
                            label: "About ClipFlow"
                        ) {
                            NSApp.sendAction(#selector(AppDelegate.openAbout), to: nil, from: nil)
                        }

                        CFLinkBtn(
                            icon: AnyView(CFIcon(type: .star, size: 13)),
                            label: "Show Welcome Screen"
                        ) {
                            NSApp.sendAction(#selector(AppDelegate.openWelcome), to: nil, from: nil)
                        }

                        CFLinkBtn(
                            icon: AnyView(CFIcon(type: .link, size: 13)),
                            label: L("view_on_github")
                        ) {
                            if let url = URL(string: "https://github.com/relbns/ClipFlow") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                .padding(20)
                .background(theme.surface)
                .cornerRadius(12)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .background(theme.surfaceDeep)
    }
}

#Preview {
    SettingsView()
}
