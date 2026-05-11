import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject private var languageManager: LanguageManager
    @AppStorage("preferredLanguage") private var preferredLanguage = "system"

    @Environment(\.cfTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("language"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.textStrong)

                    Text("Configure interface language and text direction")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSubtle)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Settings Rows
                VStack(spacing: 0) {
                    CFSettingsRow(
                        label: L("interface_language"),
                        hint: preferredLanguage == "system" ? L("system_default") : (preferredLanguage == "he" ? L("hebrew") : L("english")),
                        isLast: true
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
    LanguageSettingsView()
        .cfAutoTheme()
        .environmentObject(LanguageManager.shared)
}
