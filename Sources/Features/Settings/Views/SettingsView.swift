import SwiftUI

struct SettingsView: View {
    @AppStorage("preferencesTab") private var savedTab = 0
    @State private var shownTab: Int?
    var onTabTitle: (String) -> Void = { _ in }
    @Environment(\.cfTheme) var theme

    private var selectedTab: Int { shownTab ?? savedTab }

    private let tabs: [(icon: CFIcon.IconType, key: String, accent: Color)] = [
        (.gear, "tab_general", BrandPalette.SettingsTab.general),
        (.star, "tab_appearance", BrandPalette.SettingsTab.appearance),
        (.bolt, "tab_expansion", BrandPalette.SettingsTab.expansion),
        (.key, "tab_hotkeys", BrandPalette.SettingsTab.hotkeys),
        (.cloud, "tab_backup", BrandPalette.SettingsTab.sync),
        (.lock, "tab_privacy", BrandPalette.SettingsTab.privacy),
        (.hebrew, "tab_language", BrandPalette.SettingsTab.language)
    ]

    /// The last tab is remembered, so a language switch that rebuilds the window keeps it.
    init(initialTab: Int? = nil, onTabTitle: @escaping (String) -> Void = { _ in }) {
        _shownTab = State(initialValue: initialTab)
        self.onTabTitle = onTabTitle
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 4) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: { shownTab = nil; savedTab = index }) {
                        VStack(spacing: 4) {
                            CFGradientBadge(icon: tab.icon, accent: tab.accent)
                            Text(L(tab.key))
                                .font(.system(size: 11))
                                .foregroundColor(selectedTab == index ? theme.textStrong : theme.textMid)
                                .lineLimit(1)
                        }
                        .frame(minWidth: 70)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(selectedTab == index ? theme.fill2 : Color.clear)
                        .cornerRadius(7)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .focusEffectDisabled()
                    .accessibilityLabel(L(tab.key))
                    .accessibilityAddTraits(selectedTab == index ? .isSelected : [])
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(theme.titlebarBg)
            .overlay(Rectangle().fill(theme.stroke).frame(height: 1), alignment: .bottom)

            Group {
                switch selectedTab {
                case 1: AppearanceSettingsView()
                case 2: TextExpansionSettingsView()
                case 3: HotkeySettingsView()
                case 4: BackupSettingsView()
                case 5: PrivacySettingsView()
                case 6: LanguageSettingsView()
                default: GeneralSettingsView()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(theme.surface)
        }
        .frame(width: 760, height: 620)
        .onAppear { onTabTitle(L(tabs[min(selectedTab, tabs.count - 1)].key)) }
        .onChange(of: selectedTab) { _, index in onTabTitle(L(tabs[min(index, tabs.count - 1)].key)) }
    }
}

/// A Preferences tab body: rows directly on the window surface, as in the design.
struct SettingsPage<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                content()
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage("maxHistoryItems") private var maxHistoryItems = 30.0
    @AppStorage("removeDuplicates") private var removeDuplicates = true
    @AppStorage("moveUsedToTop") private var moveUsedToTop = true
    @AppStorage("startMonitoring") private var recordHistory = true
    @AppStorage("alwaysPastePlainText") private var alwaysPastePlainText = false
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var confirmingClear = false

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("pref_launch_at_login"), hint: L("pref_launch_at_login_hint")) {
                CFToggle(isOn: Binding(get: { launchAtLogin }, set: setLaunchAtLogin))
                    .accessibilityLabel(L("pref_launch_at_login"))
            }
            CFSettingsRow(label: L("pref_record_history"), hint: L("pref_record_history_hint")) {
                CFToggle(isOn: $recordHistory).accessibilityLabel(L("pref_record_history"))
            }
            CFSettingsRow(label: L("pref_history_size"), hint: L("pref_history_size_hint")) {
                CFSlider(value: $maxHistoryItems, range: 10...100, displayValue: "\(Int(maxHistoryItems))")
                    .accessibilityLabel(L("pref_history_size"))
            }
            CFSettingsRow(label: L("pref_remove_duplicates"), hint: L("pref_remove_duplicates_hint")) {
                CFToggle(isOn: $removeDuplicates).accessibilityLabel(L("pref_remove_duplicates"))
            }
            CFSettingsRow(label: L("pref_move_used_to_top"), hint: L("pref_move_used_to_top_hint")) {
                CFToggle(isOn: $moveUsedToTop).accessibilityLabel(L("pref_move_used_to_top"))
            }
            CFSettingsRow(label: L("pref_always_plain"), hint: L("pref_always_plain_hint")) {
                CFToggle(isOn: $alwaysPastePlainText).accessibilityLabel(L("pref_always_plain"))
            }
            CFSettingsRow(label: L("pref_clear_history"), hint: L("pref_clear_history_hint")) {
                CFToolbarBtn(label: L("pref_clear_history_button")) { confirmingClear = true }
            }
            CFSettingsRow(label: L("pref_welcome"), hint: L("pref_welcome_hint")) {
                CFToolbarBtn(label: L("pref_welcome_button")) {
                    NSApp.sendAction(#selector(AppDelegate.openWelcome), to: nil, from: nil)
                }
            }
            CFSettingsRow(label: L("pref_about"), hint: L("pref_about_hint"), isLast: true) {
                CFToolbarBtn(label: L("pref_about_button")) {
                    NSApp.sendAction(#selector(AppDelegate.openAbout), to: nil, from: nil)
                }
            }
        }
        .onAppear { launchAtLogin = LaunchAtLogin.isEnabled }
        .alert(L("clear_history_confirm_title"), isPresented: $confirmingClear) {
            Button(L("pref_clear_history_button"), role: .destructive) {
                NotificationCenter.default.post(name: .clearClipboardHistory, object: nil)
            }
            Button(L("cancel"), role: .cancel) {}
        } message: {
            Text(L("clear_history_confirm_message"))
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        launchAtLogin = LaunchAtLogin.set(enabled)
    }
}

extension Notification.Name {
    static let clearClipboardHistory = Notification.Name("ClearClipboardHistory")
}
