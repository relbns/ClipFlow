import SwiftUI

struct TextExpansionSettingsView: View {
    @AppStorage("textExpansionEnabled") private var expansionEnabled = true
    @AppStorage("expandAfter") private var expandAfter = "delimiter"
    @AppStorage("playSoundOnExpand") private var playSound = false
    @AppStorage("showNotificationOnExpand") private var showNotification = false

    var body: some View {
        Form {
            Section("Text Expansion") {
                Toggle("Enable text expansion", isOn: $expansionEnabled)

                Text("Automatically expand abbreviations as you type")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Trigger") {
                Picker("Expand after:", selection: $expandAfter) {
                    Text("Delimiter (space, tab, punctuation)").tag("delimiter")
                    Text("Space only").tag("space")
                    Text("Any character").tag("any")
                    Text("Tab only").tag("tab")
                    Text("Enter only").tag("enter")
                }

                Text("Choose what character triggers snippet expansion")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Feedback") {
                Toggle("Play sound on expansion", isOn: $playSound)
                Toggle("Show brief notification", isOn: $showNotification)
            }

            Section("Permissions") {
                PermissionStatusView()
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

struct PermissionStatusView: View {
    @State private var hasAccessibility = AXIsProcessTrusted()

    var body: some View {
        HStack {
            if hasAccessibility {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Accessibility permission granted")
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                VStack(alignment: .leading) {
                    Text("Accessibility permission required")
                    Text("Text expansion needs permission to monitor keystrokes")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Open System Settings") {
                    openAccessibilitySettings()
                }
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
}
