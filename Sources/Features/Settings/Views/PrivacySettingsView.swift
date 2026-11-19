import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.cfTheme) private var theme

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
            CFSettingsRow(label: L("pref_history_excluded"), hint: L("pref_history_excluded_hint"), isLast: true) {
                ExcludedAppsField(scope: .history)
            }
        }
    }
}
