import SwiftUI

struct SyncSettingsView: View {
    @AppStorage("iCloudSyncEnabled") private var iCloudEnabled = false
    @State private var lastSyncDate: Date?
    @State private var isSyncing = false

    var body: some View {
        Form {
            Section("iCloud Sync") {
                Toggle("Sync snippets via iCloud", isOn: $iCloudEnabled)

                if iCloudEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                                .foregroundColor(isSyncing ? .orange : .green)
                                .symbolEffect(.pulse, isActive: isSyncing)

                            if let lastSync = lastSyncDate {
                                Text("Last synced: \(lastSync.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never synced")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Button(action: syncNow) {
                            Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        }
                        .disabled(isSyncing)
                    }
                }

                Text("Syncs all snippets and groups across your devices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Export / Import") {
                Button(action: exportSnippets) {
                    Label("Export All Snippets...", systemImage: "square.and.arrow.up")
                }

                Button(action: importSnippets) {
                    Label("Import Snippets...", systemImage: "square.and.arrow.down")
                }

                Text("Export to JSON format (Coming Soon)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Section("Advanced Sync") {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("GitHub Gist integration (Coming Soon)", isOn: .constant(false))
                        .disabled(true)

                    Toggle("Google Drive sync (Coming Soon)", isOn: .constant(false))
                        .disabled(true)
                }

                Text("Additional sync options will be available in future updates")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func syncNow() {
        isSyncing = true
        Task {
            // Simulate sync
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                lastSyncDate = Date()
                isSyncing = false
            }
        }
    }

    private func exportSnippets() {
        // TODO: Implement export
        print("📤 Exporting snippets...")
    }

    private func importSnippets() {
        // TODO: Implement import
        print("📥 Importing snippets...")
    }
}

#Preview {
    SyncSettingsView()
}
