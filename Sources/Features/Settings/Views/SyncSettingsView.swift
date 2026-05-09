import SwiftUI
import UniformTypeIdentifiers

struct SyncSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("iCloudSyncEnabled") private var iCloudEnabled = false {
        didSet {
            if iCloudEnabled {
                iCloudService.enableAutoSync()
            } else {
                iCloudService.disableAutoSync()
            }
        }
    }
    @StateObject private var iCloudService: iCloudSyncService
    @State private var showingExportPicker = false
    @State private var showingImportPicker = false
    @State private var exportData: Data?
    @State private var importResult: ImportResult?
    @State private var showingImportAlert = false

    init() {
        _iCloudService = StateObject(wrappedValue: iCloudSyncService(context: CoreDataStack.shared.viewContext))
    }

    var body: some View {
        Form {
            Section("iCloud Sync") {
                Toggle("Sync snippets via iCloud", isOn: $iCloudEnabled)

                if iCloudEnabled {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: iCloudService.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle.fill")
                                .foregroundColor(iCloudService.isSyncing ? .orange : .green)
                                .symbolEffect(.pulse, isActive: iCloudService.isSyncing)

                            if let lastSync = iCloudService.lastSyncDate {
                                Text("Last synced: \(lastSync.formatted(.relative(presentation: .named)))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Never synced")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        HStack {
                            Button(action: syncNow) {
                                Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(iCloudService.isSyncing)

                            Button(action: restoreFromiCloud) {
                                Label("Restore from iCloud", systemImage: "arrow.down.circle")
                            }
                            .disabled(iCloudService.isSyncing)
                        }

                        if let error = iCloudService.syncError {
                            Text(error.localizedDescription)
                                .font(.caption)
                                .foregroundColor(.red)
                        }
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
        .background(exportFilePickerView)
        .background(importFilePickerView)
        .background(importResultAlert)
    }

    private func syncNow() {
        Task {
            await iCloudService.sync()
        }
    }

    private func restoreFromiCloud() {
        Task {
            do {
                try await iCloudService.restoreFromiCloud()
            } catch {
                print("❌ Restore failed: \(error)")
            }
        }
    }

    private func exportSnippets() {
        Task {
            let exporter = SnippetExporter(context: viewContext)
            do {
                let data = try await exporter.exportAll()
                await MainActor.run {
                    exportData = data
                    showingExportPicker = true
                }
            } catch {
                print("❌ Export failed: \(error)")
            }
        }
    }

    private func importSnippets() {
        showingImportPicker = true
    }

    private func performImport(from url: URL) {
        Task {
            do {
                let data = try Data(contentsOf: url)
                let exporter = SnippetExporter(context: viewContext)
                let result = try await exporter.importFromJSON(data, mergeStrategy: .skip)

                await MainActor.run {
                    importResult = result
                    showingImportAlert = true
                }
            } catch {
                print("❌ Import failed: \(error)")
            }
        }
    }
}

extension SyncSettingsView {
    var exportFilePickerView: some View {
        EmptyView()
            .fileExporter(
                isPresented: $showingExportPicker,
                document: JSONDocument(data: exportData ?? Data()),
                contentType: .json,
                defaultFilename: "ClipFlow-Snippets-\(Date().formatted(.iso8601.year().month().day()))"
            ) { result in
                switch result {
                case .success:
                    print("✅ Export successful")
                case .failure(let error):
                    print("❌ Export error: \(error)")
                }
            }
    }

    var importFilePickerView: some View {
        EmptyView()
            .fileImporter(
                isPresented: $showingImportPicker,
                allowedContentTypes: [.json],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    if let url = urls.first {
                        performImport(from: url)
                    }
                case .failure(let error):
                    print("❌ Import error: \(error)")
                }
            }
    }

    var importResultAlert: some View {
        Group {
            if let result = importResult {
                Text("")
                    .alert("Import Complete", isPresented: $showingImportAlert) {
                        Button("OK") {
                            importResult = nil
                        }
                    } message: {
                        Text("Imported: \(result.imported)\nSkipped: \(result.skipped)\nConflicts: \(result.conflicts.count)")
                    }
            }
        }
    }
}

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: data)
    }
}

#Preview {
    SyncSettingsView()
}
