import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct BackupSettingsView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @State private var exportDocument: JSONDocument?
    @State private var showingExporter = false
    @State private var showingImporter = false
    @State private var message: (title: String, body: String)?
    @AppStorage(FolderSync.enabledKey) private var syncEnabled = false
    @AppStorage(FolderSync.settingsKey) private var syncSettings = true
    @AppStorage(FolderSync.pinsKey) private var syncPins = true
    @AppStorage(FolderSync.folderKey) private var syncFolderPath = ""
    @ObservedObject private var sync = FolderSync.shared
    @Environment(\.cfTheme) private var theme

    var body: some View {
        SettingsPage {
            CFSettingsRow(label: L("sync_enabled"), hint: L("sync_enabled_hint")) {
                CFToggle(isOn: Binding(get: { syncEnabled }, set: { syncEnabled = $0; sync.syncSoon() }))
                    .accessibilityLabel(L("sync_enabled"))
            }
            if syncEnabled {
                CFSettingsRow(label: L("sync_folder"), hint: L("sync_folder_hint")) {
                    VStack(alignment: .trailing, spacing: 6) {
                        Text(displayPath)
                            .font(.system(size: 11))
                            .foregroundColor(theme.textMid)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: 260, alignment: .trailing)
                            .environment(\.layoutDirection, .leftToRight)
                        CFToolbarBtn(label: L("sync_folder_choose")) { chooseFolder() }
                    }
                }
                CFSettingsRow(label: L("sync_settings"), hint: L("sync_settings_hint")) {
                    CFToggle(isOn: $syncSettings).accessibilityLabel(L("sync_settings"))
                }
                CFSettingsRow(label: L("sync_pins"), hint: L("sync_pins_hint")) {
                    CFToggle(isOn: $syncPins).accessibilityLabel(L("sync_pins"))
                }
                CFSettingsRow(label: L("sync_status"), hint: statusText) {
                    CFToolbarBtn(label: L("sync_now")) { Task { await sync.sync() } }
                }
            }
            CFSettingsRow(label: L("pref_export"), hint: L("pref_export_hint")) {
                CFToolbarBtn(label: L("pref_export_button")) { export() }
            }
            CFSettingsRow(label: L("pref_import"), hint: L("pref_import_hint"), isLast: true) {
                CFToolbarBtn(label: L("pref_import_button")) { showingImporter = true }
            }
        }
        .fileExporter(
            isPresented: $showingExporter,
            document: exportDocument ?? JSONDocument(data: Data()),
            contentType: .json,
            defaultFilename: "ClipFlow-Snippets-\(Date().formatted(.iso8601.year().month().day()))"
        ) { result in
            if case .failure(let error) = result {
                message = (L("export_failed"), error.localizedDescription)
            }
        }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: Self.importTypes) { result in
            switch result {
            case .success(let url): importSnippets(from: url)
            case .failure(let error): message = (L("import_failed"), error.localizedDescription)
            }
        }
        .alert(message?.title ?? "", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
            Button(L("ok")) { message = nil }
        } message: {
            Text(message?.body ?? "")
        }
    }

    /// "iCloud Drive/ClipFlow" or "GoogleDrive-…/My Drive/ClipFlow" rather than the Library path behind them.
    private var displayPath: String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return sync.folder.path
            .replacingOccurrences(of: "\(home)/Library/Mobile Documents/com~apple~CloudDocs", with: "iCloud Drive")
            .replacingOccurrences(of: "\(home)/Library/CloudStorage/", with: "")
            .replacingOccurrences(of: home, with: "~")
    }

    private var statusText: String {
        switch sync.status {
        case .off: return L("sync_status_waiting")
        case .syncing: return L("sync_status_syncing")
        case .synced(let date, let otherMacs):
            let others = otherMacs == 0 ? L("sync_other_macs_none") : L("sync_other_macs", count: otherMacs)
            return L("sync_status_synced", date.formatted(date: .omitted, time: .shortened)) + " · " + others
        case .failed(let reason): return L("sync_status_failed", reason)
        }
    }

    /// A different folder holds a different set of Macs, so this Mac joins it afresh.
    private func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.directoryURL = sync.folder.deletingLastPathComponent()
        panel.prompt = L("sync_folder_choose")
        guard panel.runModal() == .OK, let url = panel.url, url.path != sync.folder.path else { return }
        syncFolderPath = url.path
        sync.reset()
        sync.syncSoon()
    }

    private func export() {
        Task { @MainActor in
            do {
                exportDocument = JSONDocument(data: try await SnippetExporter(context: viewContext).exportAll())
                showingExporter = true
            } catch {
                message = (L("export_failed"), error.localizedDescription)
            }
        }
    }

    private static let importTypes: [UTType] = [.json, .commaSeparatedText, .propertyList, .xml]
        + [UTType(filenameExtension: "textexpander")].compactMap { $0 }

    private func importSnippets(from url: URL) {
        Task { @MainActor in
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let data = try Data(contentsOf: url)
                let exporter = SnippetExporter(context: viewContext)
                guard TextExpanderImport.canRead(fileExtension: url.pathExtension) else {
                    let result = try await exporter.importFromJSON(data, mergeStrategy: .skip)
                    message = (L("import_complete"), L("import_result", result.imported, result.skipped))
                    return
                }
                let parsed = try TextExpanderImport.parse(data, fileName: url.lastPathComponent)
                let result = try exporter.importTextExpander(parsed)
                var lines = [L("import_result", result.imported, result.skipped)]
                if !parsed.scriptSnippets.isEmpty {
                    lines.append(L("import_scripts_skipped", count: parsed.scriptSnippets.count) + " " + parsed.scriptSnippets.joined(separator: ", "))
                }
                let offRule = parsed.groups.flatMap(\.snippets).map(\.abbreviation)
                    .filter { SnippetEditorModel.abbreviationError($0) != nil }
                if !offRule.isEmpty {
                    lines.append(L("import_abbreviations_off_rule", offRule.joined(separator: ", ")))
                }
                if !parsed.unsupportedMacros.isEmpty {
                    lines.append(L("import_unsupported_macros", parsed.unsupportedMacros.sorted().joined(separator: ", ")))
                }
                message = (L("import_complete"), lines.joined(separator: "\n\n"))
            } catch {
                message = (L("import_failed"), error.localizedDescription)
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
        FileWrapper(regularFileWithContents: data)
    }
}
