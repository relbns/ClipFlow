import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager

    private let choices = ["system", "en", "he"]

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("pref_interface_language"), hint: L("pref_interface_language_hint"), isLast: true) {
                CFSegmentedControl(
                    selection: Binding(
                        get: { choices.firstIndex(of: languageManager.choice) ?? 0 },
                        set: { languageManager.setLanguage(choices[$0]) }
                    ),
                    options: [L("language_system"), "English", "עברית"]
                )
                .frame(maxWidth: 320)
            }
        }
    }
}
