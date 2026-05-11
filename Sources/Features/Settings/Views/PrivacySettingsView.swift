import SwiftUI

struct PrivacySettingsView: View {
    @Environment(\.cfTheme) var theme

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text(L("privacy"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(theme.textStrong)

                    Text("Control what ClipFlow can access and monitor")
                        .font(.system(size: 13))
                        .foregroundColor(theme.textSubtle)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)

                // Placeholder
                Text("Privacy settings coming soon")
                    .font(.system(size: 13))
                    .foregroundColor(theme.textMuted)
                    .padding(24)
                    .frame(maxWidth: .infinity)
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
    PrivacySettingsView()
        .cfAutoTheme()
}
