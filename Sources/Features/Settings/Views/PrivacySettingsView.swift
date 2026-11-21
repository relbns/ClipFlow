import SwiftUI

struct PrivacySettingsView: View {
    @AppStorage(SensitiveText.handlingKey) private var handling = SensitiveHandling.expire.rawValue
    @AppStorage(SensitiveText.minutesKey) private var minutes = 5
    @AppStorage(SensitiveText.clearClipboardKey) private var clearClipboard = false
    @AppStorage(SensitiveKind.oneTimeCode.defaultsKey) private var detectCodes = true
    @AppStorage(SensitiveKind.cardNumber.defaultsKey) private var detectCards = true
    @AppStorage(SensitiveKind.iban.defaultsKey) private var detectIBANs = true
    @Environment(\.cfTheme) private var theme

    private let handlings = SensitiveHandling.allCases

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("pref_passwords"), hint: L("pref_passwords_hint")) {
                HStack(spacing: 6) {
                    CFIcon(type: .lock, size: 13, stroke: 1.8)
                    Text(L("always_on")).font(.system(size: 12))
                }
                .foregroundColor(theme.textMuted)
                .padding(.top, 2)
            }
            CFSettingsRow(label: L("pref_sensitive"), hint: L("pref_sensitive_hint")) {
                CFSegmentedControl(
                    selection: Binding(
                        get: { handlings.firstIndex { $0.rawValue == handling } ?? 1 },
                        set: { handling = handlings[$0].rawValue }
                    ),
                    options: handlings.map { L("sensitive_\($0.rawValue)") }
                )
            }
            if handling != SensitiveHandling.keep.rawValue {
                CFSettingsRow(label: L("pref_sensitive_kinds"), hint: L("pref_sensitive_kinds_hint")) {
                    Menu(kindsSummary) {
                        Toggle(L("sensitive_kind_codes"), isOn: $detectCodes)
                        Toggle(L("sensitive_kind_cards"), isOn: $detectCards)
                        Toggle(L("sensitive_kind_ibans"), isOn: $detectIBANs)
                    }
                    .frame(maxWidth: 260)
                    .accessibilityLabel(L("pref_sensitive_kinds"))
                }
            }
            if handling == SensitiveHandling.expire.rawValue {
                CFSettingsRow(label: L("pref_sensitive_after"), hint: L("pref_sensitive_after_hint")) {
                    CFSegmentedControl(
                        selection: Binding(
                            get: { SensitiveText.minuteChoices.firstIndex(of: minutes) ?? 1 },
                            set: { minutes = SensitiveText.minuteChoices[$0] }
                        ),
                        options: SensitiveText.minuteChoices.map { $0 == 60 ? L("sensitive_one_hour") : L("editor_minutes", $0) }
                    )
                }
                CFSettingsRow(label: L("pref_sensitive_clear_clipboard"), hint: L("pref_sensitive_clear_clipboard_hint")) {
                    CFToggle(isOn: $clearClipboard).accessibilityLabel(L("pref_sensitive_clear_clipboard"))
                }
            }
            CFSettingsRow(label: L("pref_history_excluded"), hint: L("pref_history_excluded_hint"), isLast: true) {
                ExcludedAppsField(scope: .history)
            }
        }
    }

    private var kindsSummary: String {
        let names = [
            (detectCodes, L("sensitive_kind_codes")),
            (detectCards, L("sensitive_kind_cards")),
            (detectIBANs, L("sensitive_kind_ibans"))
        ].filter(\.0).map(\.1)
        if names.isEmpty { return L("sensitive_kind_none") }
        return names.count == 3 ? L("sensitive_kind_all") : names.joined(separator: ", ")
    }
}
