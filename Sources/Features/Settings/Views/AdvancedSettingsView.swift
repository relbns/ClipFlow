import SwiftUI

struct AdvancedSettingsView: View {
    @AppStorage("clipboardCheckInterval") private var checkInterval = 750.0
    @AppStorage("storeHistoryLocally") private var storeLocally = true
    @AppStorage("neverSyncPasswords") private var neverSyncPasswords = true
    @AppStorage("clearHistoryOnQuit") private var clearOnQuit = false
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true

    @State private var storageSize = "12.4 MB"
    @State private var databasePath = "~/Library/Application Support/ClipFlow/"

    var body: some View {
        Form {
            Section("Performance") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Clipboard check interval:")
                        .font(.body)

                    HStack {
                        Slider(value: $checkInterval, in: 100...2000, step: 50)
                        Text("\(Int(checkInterval)) μs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 70)
                    }

                    Text("Lower values = more responsive, higher CPU usage")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Storage") {
                LabeledContent("Database location:", value: databasePath)
                    .font(.caption)

                LabeledContent("Storage size:", value: storageSize)

                Button(action: cleanUpOldData) {
                    Label("Clean Up Old Data...", systemImage: "trash")
                }

                Text("Remove clipboard items older than 30 days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Privacy") {
                Toggle("Store clipboard history locally", isOn: $storeLocally)

                Toggle("Never sync passwords/keys", isOn: $neverSyncPasswords)

                Toggle("Clear history on quit", isOn: $clearOnQuit)

                Text("When enabled, all clipboard history is deleted when ClipFlow quits")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Updates") {
                Toggle("Check for updates automatically", isOn: $autoCheckUpdates)

                HStack {
                    Button("Check Now") {
                        checkForUpdates()
                    }

                    Spacer()

                    Text("Version 1.0.0 (1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Debug") {
                Button("Reset All Settings") {
                    resetSettings()
                }
                .foregroundColor(.red)

                Button("Open Log Files...") {
                    openLogs()
                }

                Text("For troubleshooting issues")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func cleanUpOldData() {
        // TODO: Implement cleanup
        print("🗑️ Cleaning up old data...")
    }

    private func checkForUpdates() {
        // TODO: Implement update check
        print("🔄 Checking for updates...")
    }

    private func resetSettings() {
        // TODO: Implement reset
        print("⚠️ Resetting all settings...")
    }

    private func openLogs() {
        let logsURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/ClipFlow")

        NSWorkspace.shared.open(logsURL)
    }
}

#Preview {
    AdvancedSettingsView()
}
